//
//  ConditionalModifier.swift
//  Cards
//
//  Created by Serby, Paul on 23/01/2025.
//

import SwiftUI

extension View {
    @ViewBuilder
    func conditionalModifier<Content: View>(@ViewBuilder transform: (Self) -> Content) -> some View {
        transform(self)
    }
}
