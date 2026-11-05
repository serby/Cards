#!/usr/bin/env python3
"""Validate the checked-in raw App Store captures in screenshots/<locale>/.

Run locally by `make store-screenshots` and `make validate-screenshots` before
the captures are committed. CI does not run it: it only checks that the
composed store images are present (scripts/check-store-images.ts)."""

from __future__ import annotations

import struct
from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parent.parent
SCREENSHOTS_DIR = PROJECT_DIR / "screenshots"
IPHONE = (1320, 2868)
IPAD = (2064, 2752)
DUO = (1398, 2034)  # iPhone Duo, outer display: the simulator boots folded
SCREENS = ("01_CardList", "02_CardDetail", "03_EditCard", "04_LocationPicker")
# The widget shot is a crop of the Home Screen round the widget, whatever size
# the widget takes there (None).
REFERENCES = {
    **{f"{name}.png": IPHONE for name in SCREENS},
    **{f"{name}_Duo.png": DUO for name in SCREENS},
    **{f"{name}_iPad.png": IPAD for name in SCREENS},
    "05_Widget.png": (None, None),
    "05_Widget_Duo.png": (None, None),
    "05_Widget_iPad.png": (None, None),
}
EXPECTED = {"en-GB": REFERENCES, "en-US": REFERENCES}
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
        path.name for path in SCREENSHOTS_DIR.iterdir()
        if path.is_dir() and not path.name.startswith(".") and path.name != "store"
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
            expected_width, expected_height = expected_dimensions
            if (expected_width is not None and width != expected_width) or (
                expected_height is not None and height != expected_height
            ):
                errors.append(
                    f"{locale}/{filename}: expected {expected_width or 'any'}x{expected_height or 'any'}, "
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




def main() -> int:
    errors = validate_references()
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("Screenshot validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
