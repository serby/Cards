import Foundation
import SwiftUI

/// Reads a file the person chose, such as an export picked in the Files
/// picker, injected so nothing but the live value touches the file system.
public struct FileReader: Sendable {
    /// The contents of the file at `url`. Throws if it cannot be read.
    public var read: @MainActor @Sendable (URL) throws -> Data

    public init(read: @escaping @MainActor @Sendable (URL) throws -> Data) {
        self.read = read
    }
}

public extension FileReader {
    /// The file system. A file from the Files picker is outside the app's
    /// sandbox, so it is read inside its security-scoped access.
    static let live = Self { url in
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try Data(contentsOf: url)
    }
}

private struct FileReaderKey: EnvironmentKey {
    static let defaultValue = FileReader.live
}

public extension EnvironmentValues {
    var fileReader: FileReader {
        get { self[FileReaderKey.self] }
        set { self[FileReaderKey.self] = newValue }
    }
}
