import SwiftUI

public struct Spinner: View {
    public let isLoading: Bool
    public let graceTime: TimeInterval

    @State private var showSpinner = false

    public init(isLoading: Bool, graceTime: TimeInterval = 0) {
        self.isLoading = isLoading
        self.graceTime = graceTime
    }

    public var body: some View {
        Group {
            if showSpinner {
                ProgressView()
            }
        }
        .task(id: isLoading) {
            if isLoading {
                if graceTime > 0 {
                    try? await Task.sleep(for: .seconds(graceTime))
                    if isLoading { showSpinner = true }
                } else {
                    showSpinner = true
                }
            } else {
                showSpinner = false
            }
        }
    }
}

public extension View {
    func spinner(_ isLoading: Bool, graceTime: TimeInterval = 0) -> some View {
        overlay {
            Spinner(isLoading: isLoading, graceTime: graceTime)
        }
    }
}
