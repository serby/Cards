import SwiftUI

/// Stand-in for the camera, for stories and previews: a black picture under the
/// scanner's real controls, which behave as they do over the camera. A tap shows
/// the focus square for a moment, and the torch button turns on and off.
public struct ScannerPlaceholderView: View {
    @State private var state: ScannerState
    @State private var taps = 0

    public init(hasTorch: Bool = true) {
        _state = State(initialValue: ScannerState(hasTorch: hasTorch))
    }

    public var body: some View {
        ZStack {
            Rectangle().fill(.black)
            Text(verbatim: "Camera preview")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .accessibilityHidden(true)
            ScannerControlsView(
                state: state,
                actions: ScannerActions(
                    focus: { point in focus(at: point) },
                    setTorch: { isOn in state.torchIsOn = isOn }
                )
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func focus(at point: CGPoint) {
        taps += 1
        let mark = FocusMark(point: point, id: taps)
        state.focus = mark
        Task {
            try? await Task.sleep(for: FocusMark.duration)
            if state.focus == mark {
                state.focus = nil
            }
        }
    }
}
