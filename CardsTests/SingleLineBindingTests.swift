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
        let field = Field("Local Roa")
        field.binding.wrappedValue = "Local Roast"
        #expect(field.text == "Local Roast")
        #expect(field.returns == 0)
    }

    /// Dropped in the same update, the value would be the one the field
    /// already had, SwiftUI would see no change, and the field drew blank.
    @Test func returnIsStoredThenDroppedAndEndsTheField() async {
        let field = Field("Local Roast Coffee")
        field.binding.wrappedValue = "Local Roast Coffee\n"
        #expect(field.text == "Local Roast Coffee\n")
        await field.settle()
        #expect(field.text == "Local Roast Coffee")
        #expect(field.returns == 1)
    }

    @Test func pastedLineBreaksAreDropped() async {
        let field = Field("")
        field.binding.wrappedValue = "Local\nRoast\r\nCoffee"
        await field.settle()
        #expect(field.text == "LocalRoastCoffee")
        #expect(field.returns == 1)
    }
}
