import Foundation

/// Open source software built into the app, with the licence it is used under,
/// which Settings > Acknowledgements shows in full (PLAT-12). Every package in
/// the project's Package.resolved is here, or among the ones Firebase's
/// package pins without building them into the app; a unit test checks it.
public struct OpenSourceLibrary: Identifiable, Hashable, Sendable {
    /// The library's name, as its project writes it.
    public let name: String
    /// Where the project lives, the package's repository without ".git".
    public let url: URL?
    /// The licence's name, as "MIT License".
    public let licenceName: String
    /// The licence in full, as the project ships it, copyright line included.
    public let licenceText: String

    public var id: String { name }

    public init(name: String, url: URL?, licenceName: String, licenceText: String) {
        self.name = name
        self.url = url
        self.licenceName = licenceName
        self.licenceText = licenceText
    }
}

public extension OpenSourceLibrary {
    /// Every library the app is built with, by name.
    static let all: [OpenSourceLibrary] = [rsBarcodes, sentry, firebase, googleAppMeasurement, googleUtilities, promises, nanopb, interop]

    /// Packages Package.resolved pins because Firebase's package names them,
    /// but whose code the analytics product never builds into the app, so
    /// they are not acknowledged as part of it.
    static let pinnedButNotBuiltIn: Set<String> = [
        "https://github.com/google/abseil-cpp-binary",
        "https://github.com/google/app-check",
        "https://github.com/googleads/google-ads-on-device-conversion-ios-sdk",
        "https://github.com/google/GoogleDataTransport",
        "https://github.com/google/grpc-binary",
        "https://github.com/google/gtm-session-fetcher",
        "https://github.com/firebase/leveldb"
    ]

    /// Sends crash reports and performance data, with Share Diagnostics on (PLAT-14).
    static let sentry = bundled("Sentry", "https://github.com/getsentry/sentry-cocoa", "MIT License", file: "sentry-cocoa")
    /// Counts which features are used, with Share Usage Data on (PLAT-15).
    static let firebase = bundled("Firebase", "https://github.com/firebase/firebase-ios-sdk", "Apache License 2.0", file: "firebase-ios-sdk")
    /// Google Analytics' measurement, which Firebase's analytics sends through.
    static let googleAppMeasurement = bundled(
        "GoogleAppMeasurement", "https://github.com/google/GoogleAppMeasurement", "Apache License 2.0", file: "GoogleAppMeasurement"
    )
    /// Firebase's shared utilities.
    static let googleUtilities = bundled(
        "GoogleUtilities", "https://github.com/google/GoogleUtilities", "Apache License 2.0", file: "GoogleUtilities"
    )
    /// Firebase's promises.
    static let promises = bundled("Promises", "https://github.com/google/promises", "Apache License 2.0", file: "promises")
    /// Firebase's encoding of what it sends.
    static let nanopb = bundled("nanopb", "https://github.com/firebase/nanopb", "zlib License", file: "nanopb")
    /// The interfaces Google's libraries share.
    static let interop = bundled(
        "Interop for Google SDKs", "https://github.com/google/interop-ios-for-google-sdks", "Apache License 2.0", file: "interop-ios-for-google-sdks"
    )

    /// A library whose licence the app bundles as "Licence-<file>.txt", as
    /// the project ships it, too long to keep in code.
    private static func bundled(_ name: String, _ url: String, _ licenceName: String, file: String) -> Self {
        let text = Bundle.main.url(forResource: "Licence-\(file)", withExtension: "txt")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        return Self(name: name, url: URL(string: url), licenceName: licenceName, licenceText: text)
    }

    /// Draws the barcodes on the card screen and in the widget.
    static let rsBarcodes = OpenSourceLibrary(
        name: "RSBarcodes_Swift",
        url: URL(string: "https://github.com/yeahdongcn/RSBarcodes_Swift"),
        licenceName: "MIT License",
        licenceText: """
            The MIT License (MIT)

            Copyright (c) 2012-2014 P.D.Q.

            Permission is hereby granted, free of charge, to any person obtaining a copy of \
            this software and associated documentation files (the "Software"), to deal in \
            the Software without restriction, including without limitation the rights to \
            use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of \
            the Software, and to permit persons to whom the Software is furnished to do so, \
            subject to the following conditions:

            The above copyright notice and this permission notice shall be included in all \
            copies or substantial portions of the Software.

            THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR \
            IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS \
            FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR \
            COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER \
            IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN \
            CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
            """
    )
}
