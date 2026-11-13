import Foundation
import SwiftUI

/// Writes a file to hand to the share sheet, such as the cards' export
/// (DATA-2), injected so nothing but the live value touches the file system.
public struct FileWriter: Sendable {
    /// Writes `data` to a file called `name`, and gives back where it is.
    /// Throws if it cannot be written.
    public var write: @MainActor @Sendable (_ data: Data, _ name: String) throws -> URL
    /// Deletes a file iOS handed the app to open, such as an export opened from
    /// Mail (DATA-11), once it is imported. A file anywhere but the app's own
    /// inbox and temporary files, such as one chosen in Files, is left alone.
    public var removeHandedOver: @MainActor @Sendable (URL) -> Void

    public init(
        write: @escaping @MainActor @Sendable (_ data: Data, _ name: String) throws -> URL,
        removeHandedOver: @escaping @MainActor @Sendable (URL) -> Void = { _ in }
    ) {
        self.write = write
        self.removeHandedOver = removeHandedOver
    }
}

public extension FileWriter {
    /// A folder of the app's own temporary files, which iOS clears out in time.
    static let live = folder(at: .temporaryDirectory.appending(path: "Export", directoryHint: .isDirectory))

    /// Files written in the folder at `url`, which holds only the latest, so
    /// exports made on other days do not pile up.
    static func folder(at url: URL) -> Self {
        Self(
            write: { data, name in
                let files = FileManager.default
                try? files.removeItem(at: url)
                try files.createDirectory(at: url, withIntermediateDirectories: true)
                let file = url.appending(path: name, directoryHint: .notDirectory)
                try data.write(to: file, options: .atomic)
                return file
            },
            removeHandedOver: { file in
                guard isHandedOver(file) else { return }
                try? FileManager.default.removeItem(at: file)
            }
        )
    }

    /// Whether `file` is a copy iOS put in the app's inbox, in Documents or
    /// its temporary files, to open, rather than a file of the person's own.
    static func isHandedOver(_ file: URL) -> Bool {
        let path = file.standardizedFileURL.path
        let own = [URL.documentsDirectory, URL.temporaryDirectory].map { $0.standardizedFileURL.path }
        return path.contains("Inbox/") && own.contains { path.hasPrefix($0) }
    }
}

private struct FileWriterKey: EnvironmentKey {
    static let defaultValue = FileWriter.live
}

public extension EnvironmentValues {
    var fileWriter: FileWriter {
        get { self[FileWriterKey.self] }
        set { self[FileWriterKey.self] = newValue }
    }
}
