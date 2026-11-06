import SwiftUI

/// What the scanner draws over the camera picture: the red guide line, a focus
/// square where you tap, and the torch button. It turns taps and pinches into
/// actions, so the live camera, or a story's stand-in, decides what they do
/// (CARD-2, BAR-6, BAR-7).
public struct ScannerControlsView: View {
    private let state: ScannerState
    private let actions: ScannerActions

    public init(state: ScannerState, actions: ScannerActions = ScannerActions()) {
        self.state = state
        self.actions = actions
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                surface(centre: CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2))

                Rectangle()
                    .fill(Color.red.opacity(0.8))
                    .frame(height: 2)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                if let focus = state.focus {
                    FocusSquare()
                        .position(focus.point)
                        .id(focus.id)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.25), value: state.focus)
            .overlay(alignment: .bottomTrailing) {
                if state.hasTorch {
                    TorchButton(isOn: state.torchIsOn) { actions.setTorch(!state.torchIsOn) }
                        .padding(10)
                }
            }
        }
    }

    /// The camera picture's stand-in for touch and VoiceOver: a tap focuses
    /// where it lands, a pinch zooms, and VoiceOver's double-tap focuses on the
    /// middle, as a person using it can't aim a tap at the card.
    private func surface(centre: CGPoint) -> some View {
        Color.clear
            .contentShape(.rect)
            .onTapGesture(coordinateSpace: .local) { location in
                actions.focus(location)
            }
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in actions.pinch(value.magnification) }
                    .onEnded { _ in actions.endPinch() }
            )
            .accessibilityElement()
            .accessibilityLabel("Barcode scanner")
            .accessibilityHint("Point the camera at a card's barcode to read it. Double-tap to focus on the middle.")
            .accessibilityAction { actions.focus(centre) }
            .accessibilityIdentifier("scannerView")
    }
}

/// The square that shows where the camera is focusing. It shrinks onto the
/// spot as it appears, or with Reduce Motion on, only fades in.
private struct FocusSquare: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasSettled = false

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .strokeBorder(Color.yellow, lineWidth: 1.5)
            .frame(width: 72, height: 72)
            .scaleEffect(hasSettled || reduceMotion ? 1 : 1.4)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                withAnimation(reduceMotion ? nil : .spring(duration: 0.3)) {
                    hasSettled = true
                }
            }
    }
}

/// Turns the torch on and off. It sits over the camera picture, which can be
/// any colour, so rather than the accent it is white on a dark circle when off
/// and dark on a white circle when on, which stay readable over any picture.
private struct TorchButton: View {
    let isOn: Bool
    let action: () -> Void

    /// A 44 point touch area that grows with the text size.
    @ScaledMetric(relativeTo: .title3) private var size: CGFloat = 44

    var body: some View {
        Button(action: action) {
            Image(systemName: isOn ? "flashlight.on.fill" : "flashlight.off.fill")
                .font(.title3)
                .foregroundStyle(isOn ? Color.black : Color.white)
                .frame(width: size, height: size)
                .background(isOn ? Color.white : Color.black.opacity(0.55), in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Torch")
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityHint("Lights up the card so the camera can read it in the dark")
        .accessibilityAddTraits(.isToggle)
        .accessibilityIdentifier("torchButton")
    }
}

#if DEBUG
#Preview("Torch off") {
    ScannerControlsView(state: ScannerState(hasTorch: true))
        .background(.black)
        .frame(height: 250)
        .padding()
}

#Preview("Torch on, focusing") {
    ScannerControlsView(
        state: ScannerState(hasTorch: true, torchIsOn: true, focus: FocusMark(point: CGPoint(x: 120, y: 90), id: 1))
    )
    .background(.black)
    .frame(height: 250)
    .padding()
}

#Preview("No torch") {
    ScannerControlsView(state: ScannerState())
        .background(.black)
        .frame(height: 250)
        .padding()
}
#endif
