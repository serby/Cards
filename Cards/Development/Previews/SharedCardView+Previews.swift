import SwiftUI

#Preview("New card") {
    SharedCardView(state: .new(.sample, places: CardLocation.samples))
}

#Preview("Already here") {
    SharedCardView(state: .alreadyAdded(.sample, places: []))
}

#Preview("Unreadable link") {
    SharedCardView(state: .unreadable)
}
