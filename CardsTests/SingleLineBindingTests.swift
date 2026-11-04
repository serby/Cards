@testable import Cards
import SwiftUI
import Testing

/// A wrapping text field takes Return as a line break; `singleLine` makes it
/// end the field instead, and must let SwiftUI see the change to do it.
@MainActor
struct SingleLineBindingTests {
    @MainActor
    final class Field {
        var text: String
        var returns = 0

        init(_ text: String) {
            self.text = text
        }

        var binding: Binding<String> {
            Binding(get: { self.text }, set: { self.text = $0 }).singleLine { self.returns += 1 }
        }

        /// Waits for the line break to be dropped, which happens after the
        /// update that stored it.
        func settle() async {
            for _ in 0..<100 where returns == 0 {
                try? await Task.sleep(for: .milliseconds(10))
            }
        }
    }

    @Test func typingGoesStraightThrough() {
        let field = Field("Cost")
        field.binding.wrappedValue = "Costa"
        #expect(field.text == "Costa")
        #expect(field.returns == 0)
    }

    /// Dropped in the same update, the value would be the one the field
    /// already had, SwiftUI would see no change, and the field drew blank.
    @Test func returnIsStoredThenDroppedAndEndsTheField() async {
        let field = Field("Costa Coffee")
        field.binding.wrappedValue = "Costa Coffee\n"
        #expect(field.text == "Costa Coffee\n")
        await field.settle()
        #expect(field.text == "Costa Coffee")
        #expect(field.returns == 1)
    }

    @Test func pastedLineBreaksAreDropped() async {
        let field = Field("")
        field.binding.wrappedValue = "Costa\nCoffee\r\nClub"
        await field.settle()
        #expect(field.text == "CostaCoffeeClub")
        #expect(field.returns == 1)
    }
}
