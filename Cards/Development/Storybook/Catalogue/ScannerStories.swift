import SwiftUI

// The camera's stand-in, its controls and the message shown instead of it.

@MainActor
let scannerPlaceholderStory = Story(
    id: "scanner-placeholder",
    title: "ScannerPlaceholderView",
    section: "Components",
    knobs: [
        .toggle("Has torch", true)
    ],
    gallery: [
        (name: "With a torch", view: AnyView(ScannerPlaceholderView().frame(height: 250))),
        (name: "No torch", view: AnyView(ScannerPlaceholderView(hasTorch: false).frame(height: 250)))
    ]
) { knobs in
    AnyView(
        ScannerPlaceholderView(hasTorch: knobs.bool("Has torch"))
            .id(knobs.bool("Has torch"))
            .frame(height: 250)
            .padding()
    )
}

/// Where the story's focus square goes, as a share of the scanner's width and height.
private struct FocusPosition {
    let name: String
    let unitPoint: UnitPoint
}

private let focusPositions = [
    FocusPosition(name: "None", unitPoint: .zero),
    FocusPosition(name: "Middle", unitPoint: .center),
    FocusPosition(name: "Top left", unitPoint: UnitPoint(x: 0.2, y: 0.25)),
    FocusPosition(name: "Bottom right", unitPoint: UnitPoint(x: 0.8, y: 0.75))
]

/// The scanner's controls over a black stand-in for the camera picture.
@MainActor
private func scannerControls(
    hasTorch: Bool,
    torchIsOn: Bool,
    focus position: String,
    actions: ScannerActions = ScannerActions()
) -> some View {
    GeometryReader { geometry in
        let focus = focusPositions.first { $0.name == position && $0.name != "None" }.map { place in
            FocusMark(
                point: CGPoint(x: geometry.size.width * place.unitPoint.x, y: geometry.size.height * place.unitPoint.y),
                id: 1
            )
        }
        ScannerControlsView(
            state: ScannerState(hasTorch: hasTorch, torchIsOn: torchIsOn, focus: focus),
            actions: actions
        )
    }
    .background(.black)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .frame(height: 250)
}

@MainActor
let scannerControlsStory = Story(
    id: "scanner-controls",
    title: "ScannerControlsView",
    section: "Components",
    knobs: [
        .toggle("Has torch", true),
        .toggle("Torch on", false),
        .options("Focus square", focusPositions.map(\.name), "None")
    ],
    gallery: [
        (name: "Torch off", view: AnyView(scannerControls(hasTorch: true, torchIsOn: false, focus: "None"))),
        (name: "Torch on", view: AnyView(scannerControls(hasTorch: true, torchIsOn: true, focus: "None"))),
        (name: "Focusing", view: AnyView(scannerControls(hasTorch: true, torchIsOn: false, focus: "Top left"))),
        (name: "No torch", view: AnyView(scannerControls(hasTorch: false, torchIsOn: false, focus: "None")))
    ]
) { knobs in
    AnyView(
        scannerControls(
            hasTorch: knobs.bool("Has torch"),
            torchIsOn: knobs.bool("Torch on"),
            focus: knobs.option("Focus square"),
            actions: ScannerActions(setTorch: { knobs.set($0, for: "Torch on") })
        )
        .padding()
    )
}

@MainActor
let cameraUnavailableStory = Story(
    id: "camera-unavailable",
    title: "CameraUnavailableView",
    section: "Components",
    knobs: [
        .options("Reason", ["denied", "unavailable"], "denied")
    ],
    gallery: [
        (name: "Access off", view: AnyView(CameraUnavailableView(reason: .denied).frame(height: 250))),
        (name: "No camera", view: AnyView(CameraUnavailableView(reason: .unavailable).frame(height: 250)))
    ]
) { knobs in
    AnyView(
        CameraUnavailableView(reason: knobs.option("Reason") == "denied" ? .denied : .unavailable)
            .frame(height: 250)
            .padding()
    )
}
