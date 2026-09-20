#!/usr/bin/env python3
"""Validate checked-in App Store screenshots and optional XCTest captures."""

from __future__ import annotations

import argparse
import json
import re
import struct
import subprocess
import tempfile
import zlib
from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parent.parent
SCREENSHOTS_DIR = PROJECT_DIR / "screenshots"
EXPECTED = {
    "en-GB": {
        "01_CardList.png": (1320, 2868),
        "01_CardList_iPad.png": (2064, 2752),
        "02_AddCard.png": (1320, 2868),
        "03_Settings.png": (1320, 2868),
    },
    "en-US": {
        "01_CardList.png": (1320, 2868),
        "01_CardList_iPad.png": (2064, 2752),
        "02_AddCard.png": (1320, 2868),
        "03_Settings.png": (1320, 2868),
    },
}
CAPTURE_SETS = {
    "iphone": ("01_CardList", "02_AddCard", "03_Settings"),
    "ipad": ("01_CardList_iPad",),
}
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def png_info(path: Path) -> tuple[int, int, int, int]:
    with path.open("rb") as image:
        if image.read(8) != PNG_SIGNATURE:
            raise ValueError("not a PNG")
        length = struct.unpack(">I", image.read(4))[0]
        if image.read(4) != b"IHDR" or length != 13:
            raise ValueError("missing PNG IHDR")
        width, height, bit_depth, color_type = struct.unpack(">IIBB", image.read(10))
    return width, height, bit_depth, color_type


def validate_references() -> list[str]:
    errors: list[str] = []
    actual_locales = {
        path.name for path in SCREENSHOTS_DIR.iterdir() if path.is_dir() and not path.name.startswith(".")
    }
    if actual_locales != set(EXPECTED):
        errors.append(
            f"locale directories: expected {sorted(EXPECTED)}, found {sorted(actual_locales)}"
        )

    for locale, expected_files in EXPECTED.items():
        locale_dir = SCREENSHOTS_DIR / locale
        actual_files = {path.name for path in locale_dir.glob("*.png")} if locale_dir.exists() else set()
        if actual_files != set(expected_files):
            errors.append(
                f"{locale}: expected {sorted(expected_files)}, found {sorted(actual_files)}"
            )
        for filename, expected_dimensions in expected_files.items():
            path = locale_dir / filename
            if not path.exists():
                continue
            try:
                width, height, bit_depth, color_type = png_info(path)
            except (OSError, ValueError, struct.error) as error:
                errors.append(f"{locale}/{filename}: {error}")
                continue
            if (width, height) != expected_dimensions:
                errors.append(
                    f"{locale}/{filename}: expected {expected_dimensions[0]}x{expected_dimensions[1]}, "
                    f"found {width}x{height}"
                )
            if bit_depth != 8 or color_type not in (2, 6):
                errors.append(
                    f"{locale}/{filename}: expected 8-bit RGB/RGBA PNG, "
                    f"found bit depth {bit_depth}, color type {color_type}"
                )
            if path.stat().st_size < 50_000:
                errors.append(f"{locale}/{filename}: file is unexpectedly small")
    return errors


def attachment_name(attachment: dict[str, object]) -> str:
    raw = str(
        attachment.get("suggestedHumanReadableName")
        or attachment.get("exportedFileName")
        or ""
    )
    return re.sub(r"_\d+_[0-9A-Fa-f-]{36}\.png$", "", raw)


def exported_attachments(export_dir: Path) -> dict[str, list[Path]]:
    manifest_path = export_dir / "manifest.json"
    with manifest_path.open() as manifest_file:
        manifest = json.load(manifest_file)
    attachments: dict[str, list[Path]] = {}
    for test_entry in manifest:
        for attachment in test_entry.get("attachments", []):
            name = attachment_name(attachment)
            exported_name = attachment.get("exportedFileName")
            if name and exported_name:
                attachments.setdefault(name, []).append(export_dir / exported_name)
    return attachments


def paeth(left: int, above: int, upper_left: int) -> int:
    estimate = left + above - upper_left
    distance_left = abs(estimate - left)
    distance_above = abs(estimate - above)
    distance_upper_left = abs(estimate - upper_left)
    if distance_left <= distance_above and distance_left <= distance_upper_left:
        return left
    if distance_above <= distance_upper_left:
        return above
    return upper_left


def decode_png(path: Path) -> tuple[int, int, bytearray]:
    data = path.read_bytes()
    offset = 8
    compressed = bytearray()
    width = height = bit_depth = color_type = interlace = 0
    while offset < len(data):
        length = struct.unpack(">I", data[offset : offset + 4])[0]
        chunk_type = data[offset + 4 : offset + 8]
        chunk = data[offset + 8 : offset + 8 + length]
        offset += 12 + length
        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type, _, _, interlace = struct.unpack(">IIBBBBB", chunk)
        elif chunk_type == b"IDAT":
            compressed.extend(chunk)
        elif chunk_type == b"IEND":
            break

    channels = {2: 3, 6: 4}.get(color_type)
    if bit_depth != 8 or channels is None or interlace != 0:
        raise ValueError(f"unsupported PNG format in {path.name}")

    raw = zlib.decompress(compressed)
    row_size = width * channels
    expected_size = height * (row_size + 1)
    if len(raw) != expected_size:
        raise ValueError(f"invalid decompressed PNG size in {path.name}")

    pixels = bytearray(width * height * 3)
    previous = bytearray(row_size)
    source_offset = 0
    destination_offset = 0
    for _ in range(height):
        filter_type = raw[source_offset]
        source_offset += 1
        encoded = raw[source_offset : source_offset + row_size]
        source_offset += row_size
        row = bytearray(row_size)
        for index, value in enumerate(encoded):
            left = row[index - channels] if index >= channels else 0
            above = previous[index]
            upper_left = previous[index - channels] if index >= channels else 0
            if filter_type == 0:
                decoded = value
            elif filter_type == 1:
                decoded = value + left
            elif filter_type == 2:
                decoded = value + above
            elif filter_type == 3:
                decoded = value + ((left + above) // 2)
            elif filter_type == 4:
                decoded = value + paeth(left, above, upper_left)
            else:
                raise ValueError(f"unsupported PNG filter {filter_type} in {path.name}")
            row[index] = decoded & 0xFF
        for index in range(0, row_size, channels):
            pixels[destination_offset : destination_offset + 3] = row[index : index + 3]
            destination_offset += 3
        previous = row
    return width, height, pixels


def visual_difference(reference: Path, capture: Path) -> tuple[float, float]:
    with tempfile.TemporaryDirectory(prefix="cards-snapshot-") as temp_dir_name:
        temp_dir = Path(temp_dir_name)
        resized_reference = temp_dir / "reference.png"
        resized_capture = temp_dir / "capture.png"
        for source, destination in (
            (reference, resized_reference),
            (capture, resized_capture),
        ):
            subprocess.run(
                [
                    "sips",
                    "--resampleHeightWidth",
                    "180",
                    "90",
                    str(source),
                    "--out",
                    str(destination),
                ],
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE,
            )

        _, _, reference_pixels = decode_png(resized_reference)
        _, _, capture_pixels = decode_png(resized_capture)
        if len(reference_pixels) != len(capture_pixels):
            raise ValueError("resized image dimensions differ")
        absolute_difference = sum(
            abs(reference_value - capture_value)
            for reference_value, capture_value in zip(reference_pixels, capture_pixels)
        )
        mean_absolute_difference = absolute_difference / len(reference_pixels)
        pixel_count = len(reference_pixels) // 3
        changed_pixels = sum(
            1
            for offset in range(0, len(reference_pixels), 3)
            if max(
                abs(reference_pixels[offset + channel] - capture_pixels[offset + channel])
                for channel in range(3)
            )
            > 30
        )
        return mean_absolute_difference, changed_pixels / pixel_count


def validate_captures(export_dir: Path, capture_set: str) -> list[str]:
    errors: list[str] = []
    attachments = exported_attachments(export_dir)
    for name in CAPTURE_SETS[capture_set]:
        candidates = attachments.get(name, [])
        if not candidates:
            errors.append(f"missing XCTest attachment: {name}")
            continue
        capture = candidates[-1]
        try:
            capture_dimensions = png_info(capture)[:2]
        except (OSError, ValueError, struct.error) as error:
            errors.append(f"{name}: {error}")
            continue
        for locale in EXPECTED:
            reference = SCREENSHOTS_DIR / locale / f"{name}.png"
            try:
                reference_dimensions = png_info(reference)[:2]
            except (OSError, ValueError, struct.error) as error:
                errors.append(f"{locale}/{name}: {error}")
                continue
            if capture_dimensions != reference_dimensions:
                errors.append(
                    f"{locale}/{name}: capture is {capture_dimensions[0]}x{capture_dimensions[1]}, "
                    f"reference is {reference_dimensions[0]}x{reference_dimensions[1]}"
                )
                continue
            try:
                mean_difference, changed_fraction = visual_difference(reference, capture)
            except (OSError, ValueError, subprocess.CalledProcessError) as error:
                errors.append(f"{locale}/{name}: unable to compare images: {error}")
                continue
            print(
                f"{locale}/{name}: mean pixel difference {mean_difference:.2f}, "
                f"materially changed pixels {changed_fraction:.1%}"
            )
            if mean_difference > 12.0 or changed_fraction > 0.18:
                errors.append(
                    f"{locale}/{name}: visual difference exceeds thresholds "
                    f"(mean {mean_difference:.2f}, changed {changed_fraction:.1%})"
                )
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--attachments",
        type=Path,
        help="xcresulttool attachment export directory to compare with all references",
    )
    parser.add_argument("--capture-set", choices=sorted(CAPTURE_SETS))
    arguments = parser.parse_args()
    if bool(arguments.attachments) != bool(arguments.capture_set):
        parser.error("--attachments and --capture-set must be supplied together")

    errors = validate_references()
    if arguments.attachments and arguments.capture_set:
        errors.extend(validate_captures(arguments.attachments, arguments.capture_set))

    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("Screenshot validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
