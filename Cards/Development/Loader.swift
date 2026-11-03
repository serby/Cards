import OSLog
import SwiftUI

/// Fakes a three-second load with signposts, for profiling the spinner in
/// Instruments. Development only.
@MainActor
@Observable
public final class Loader {
    public static let shared = Loader()
    public private(set) var isLoading = false

    private static let signpostLog = OSLog(subsystem: "net.serby.Cards", category: "Loader")

    private init() {}

    public func load() {
        let signpostID = OSSignpostID(log: Self.signpostLog)
        os_signpost(.begin, log: Self.signpostLog, name: "LoaderDisplay", signpostID: signpostID)

        let startTime = Date()
        os_signpost(.event, log: Self.signpostLog, name: "StartLoading", signpostID: signpostID)
        isLoading = true

        let loadStartTime = Date().timeIntervalSince(startTime)
        print("\u{23F1}\u{FE0F} Loading started in \(String(format: "%.3f", loadStartTime))s")

        Task {
            try? await Task.sleep(for: .seconds(3.0))
            os_signpost(.event, log: Self.signpostLog, name: "StopLoading", signpostID: signpostID)
            isLoading = false

            let totalTime = Date().timeIntervalSince(startTime)
            print("\u{23F1}\u{FE0F} Total loader time: \(String(format: "%.3f", totalTime))s")
            os_signpost(.end, log: Self.signpostLog, name: "LoaderDisplay", signpostID: signpostID)
        }
    }
}
