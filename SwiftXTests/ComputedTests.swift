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
    
    func testShouldNotRunWithoutObservers() {
        let parent = Node()
        let exp = expectation(description: "")
        exp.isInverted = true
        let computed = Computed({ () -> String in
            exp.fulfill()
            return "Parent.value: \(parent.value)"
        })
        parent.value = "Hello, World!"
        wait(for: [exp], timeout: 1)
    }
    
    func testShouldNotAutoComputeAfterManualGet() {
        let parent = Node()
        let exp = expectation(description: "")
        exp.assertForOverFulfill = true
        let computed = Computed({ () -> String in
            exp.fulfill()
            return "Parent.value: \(parent.value)"
        })
        
        let value = computed.value
        parent.value = "Hello, World!"
        wait(for: [exp], timeout: 1)
    }
    
    func testShouldStopReactingWhenBeingUnobserved() {
        let parent = Node()
        
        var exp = expectation(description: "")
        exp.expectedFulfillmentCount = 2
        exp.assertForOverFulfill = true
        let computed = Computed({ () -> String in
            exp.fulfill()
            return "\(parent.value)\(parent.value)"
        })
        
        var seenValue: String?
        let cancel = autorun {
            seenValue = computed.value
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 1)
        XCTAssert(seenValue == "\(parent.value)\(parent.value)")
        
        exp = expectation(description: "")
        exp.isInverted = true
        cancel.cancel()
        parent.value = "Hello, World!"
        wait(for: [exp], timeout: 1)
    }
    
    func testLongChainOfComputedNotBeingObserved() {
        let node = Node()
        node.value = "Hello"
        
        var exp = expectation(description: "")
        exp.isInverted = true
        
        var comps = [Computed<String>]()
        var compFunc: () -> String = {
            exp.fulfill()
            return node.value + " 0"
        }
        for i in 1...20 {
            let comp = Computed(compFunc)
            comps.append(comp)
            compFunc = {
                exp.fulfill()
                return comp.value + " \(i)"
            }
        }
        
        node.value = "Should not trigger updates..!"
        wait(for: [exp], timeout: 1)
        
        exp = expectation(description: "")
        exp.expectedFulfillmentCount = 20
        autorun {
            print("last computed has value \(comps.last?.value ?? "nil")")
        }
        wait(for: [exp], timeout: 1)
    }
    
    func testMoveObservedComputed() {
        let parent = Node()
        let left = Node()
        parent.left = left
            
        let computed = Computed({ () -> String in
            return "HEJ \(parent.left?.value ?? "nil")"
        })
        
        var exp = expectation(description: "")
        exp.expectedFulfillmentCount = 1
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

        exp = expectation(description: "")
        inTransaction {
            parent.right = parent.left
            parent.left = nil
        }

        wait(for: [exp], timeout: 1)
        XCTAssert(lastValue == "HEJ nil")

        // Update prev observed value -> should not trigger computed since it listens to the left..
        exp = expectation(description: "")
        exp.isInverted = true
        parent.right?.value = "HEJ"
        wait(for: [exp], timeout: 1)
        XCTAssert(lastValue == "HEJ nil")
    }

    func testRemoveObservedValue() {
        let parent = Node()
        let left = Node()
        parent.left = left

        let computed = Computed({ () -> String in
            return "HEJ \(parent.left?.value ?? "nil")"
        })

        var exp = expectation(description: "")
        exp.assertForOverFulfill = true
        var lastValue: String?
        autorun {
            lastValue = computed.value
            print("Got \(computed.value)")
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1)
        XCTAssert(lastValue == computed.value)

        exp = expectation(description: "")
        parent.left = nil
        wait(for: [exp], timeout: 1)
        XCTAssert(lastValue == computed.value)

        // Updating removed observable should not trigger updates anymore..
        exp = expectation(description: "")
        exp.isInverted = true
        left.value = ""
        wait(for: [exp], timeout: 1)
    }
    
    func testUpdateAnotherObservableInTheSameObservable() {
        let p = Node()
        let c = Node()
        let l = Node()
        let r = Node()
        p.left = c
        c.left = l
        c.right = r
        
        let leftValueComp = Computed<String?>({
            print("Computed")
            return p.left?.left?.value
        })
        
        var exp: XCTestExpectation? = nil
        reaction({ leftValueComp.value }, {
            print("reaction")
            print($0 ?? "nil")
            exp?.fulfill()
        })
        
        exp = expectation(description: "")
        exp?.isInverted = true
        p.left?.right = Node()
        p.left?.right?.value = "2"
        wait(for: [exp!], timeout: 1)
    }
}
