//
//  ComputedTests.swift
//  SwiftXTests
//
//  Created by Patrik Karlsson on 2020-10-12.
//  Copyright © 2020 Patrik Karlsson. All rights reserved.
//

import XCTest
import SwiftX

class ComputedTests: XCTestCase {
    func testMoveObservedComputed() {
        let parent = Node()
        let left = Node()
        parent.left = left
            
        let computed = Computed({ () -> String in
            return "HEJ \(parent.left?.value ?? "nil")"
        })
        
        var exp = expectation(description: "")
        exp.expectedFulfillmentCount = 2
        var lastValue: String?
        autorun {
            lastValue = computed.value
            print("Got \(computed.value)")
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 1)
        
        // TODO: split them out?? We'r testing too many different cases  here?
        
        exp = expectation(description: "")
        parent.left?.value = "666"
        wait(for: [exp], timeout: 1)
        XCTAssert(lastValue == "HEJ 666")
        
        inTransaction {
            parent.right = parent.left
            parent.left = nil
        }
        
        exp = expectation(description: "")
        wait(for: [exp], timeout: 1)
        XCTAssert(lastValue == "HEJ nil")
        
        exp = expectation(description: "")
        parent.right?.value = "HEJ"
        wait(for: [exp], timeout: 1)
        XCTAssert(lastValue == "HEJ nil")
    }

}
