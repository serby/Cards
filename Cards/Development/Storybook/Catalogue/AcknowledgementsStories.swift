import SwiftUI

@MainActor
let openSourceLicenceStory = Story(
    id: "open-source-licence",
    title: "OpenSourceLicenceView",
    section: "Screens",
    galleryLayout: .oneAtATime,
    knobs: [
        .text("Name", OpenSourceLibrary.rsBarcodes.name),
        .text("Project URL", OpenSourceLibrary.rsBarcodes.url?.absoluteString ?? ""),
        .text("Licence name", OpenSourceLibrary.rsBarcodes.licenceName),
        .text("Licence text", OpenSourceLibrary.rsBarcodes.licenceText)
    ],
    gallery: OpenSourceLibrary.all.map { library in
        (name: library.name, view: pushed { OpenSourceLicenceView(library: library) })
    }
) { knobs in
    // An empty Project URL knob means a library with no project website.
    let library = OpenSourceLibrary(
        name: knobs.string("Name"),
        url: knobs.string("Project URL").isEmpty ? nil : URL(string: knobs.string("Project URL")),
        licenceName: knobs.string("Licence name"),
        licenceText: knobs.string("Licence text")
    )
    return pushed { OpenSourceLicenceView(library: library) }
}
