import SwiftUI

#Preview("Two versions") {
    NavigationStack {
        ChangelogView(versions: ChangelogVersion.samples)
    }
}

#Preview("Empty") {
    NavigationStack {
        ChangelogView(versions: [])
    }
}
