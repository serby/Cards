import SwiftUI

public class PortraitHostingController<Content: View>: UIHostingController<Content> {
    override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override public var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
}

public struct PortraitLockedView<Content: View>: UIViewControllerRepresentable {
    public let content: Content

    public init(content: Content) {
        self.content = content
    }

    public func makeUIViewController(context: Context) -> PortraitHostingController<Content> {
        PortraitHostingController(rootView: content)
    }

    public func updateUIViewController(_ uiViewController: PortraitHostingController<Content>, context: Context) {
        uiViewController.rootView = content
    }
}
