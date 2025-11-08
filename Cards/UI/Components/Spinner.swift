//
//  Spinner.swift
//  Cards
//
//  Created by Serby, Paul on 08/11/2025.
//

import SwiftUI

struct Spinner: View {
    let isLoading: Bool
    let graceTime: TimeInterval
    
    @State private var showSpinner = false
    
    init(isLoading: Bool, graceTime: TimeInterval = 0) {
        self.isLoading = isLoading
        self.graceTime = graceTime
    }
    
    var body: some View {
        Group {
            if showSpinner {
                ProgressView()
            }
        }
        .task(id: isLoading) {
            if isLoading {
                if graceTime > 0 {
                    try? await Task.sleep(for: .seconds(graceTime))
                    if isLoading {
                        showSpinner = true
                    }
                } else {
                    showSpinner = true
                }
            } else {
                showSpinner = false
            }
        }
    }
}

extension View {
    func spinner(_ isLoading: Bool, graceTime: TimeInterval = 0) -> some View {
        overlay {
            Spinner(isLoading: isLoading, graceTime: graceTime)
        }
    }
}
