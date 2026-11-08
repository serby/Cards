import Foundation

/// Open source software built into the app, with the licence it is used under,
/// which Settings > Acknowledgements shows in full (PLAT-12). Every package in
/// the project's Package.resolved is here; a unit test checks it.
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
    static let all: [OpenSourceLibrary] = [rsBarcodes]

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
