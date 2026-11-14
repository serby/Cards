//
//  CardsUITestsLaunchTests.swift
//  CardsUITests
//
//  Created by Serby, Paul on 18/12/2024.
//

import XCTest

final class CardsUITestsLaunchTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        
        // Set any state the tests need, such as interface orientation, here.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 17.0, tvOS 17.0, watchOS 7.0, *) {
            let metric = XCTApplicationLaunchMetric()
            let options = XCTMeasureOptions()
            options.iterationCount = 5
            
            // Measure app launch performance
            measure(metrics: [metric], options: options) {
                XCUIApplication().launch()
            }
        }
    }
    
}
