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
    
    func testComputedUpdatingObservers() {
        let state = State()
        let exp = expectation(description: #function)
        
        exp.expectedFulfillmentCount = 4
        let computed = Computed { () -> Int in
            exp.fulfill()
            return state.count * 2
        }
        autorun {
            print("Computed is \(computed.value)")
            XCTAssert(computed.value == 0 || computed.value == 4)
            exp.fulfill()
        }
        
        state.count = 2
        
        wait(for: [exp], timeout: 1)
    }
    
    func testCyclicGraphDependency() throws {
        // 1 - 2 - 3 - 1.
        // So:
        // 3 dep: [1, 2].
        // 2 dep: [1]
        // 1 dep: N/A (atom)
        let state = State()
        
        let computed = SwiftX.computed({
            state.count * 2
        })
        
        let exp = expectation(description: "Should only update observer once no matter how many dependencies that has been updated")
        exp.assertForOverFulfill = true
        exp.expectedFulfillmentCount = 1
        
        var first = true
        autorun {
            print("[3] computed is \(computed.value) and count \(state.count)")
            XCTAssert(computed.value == (state.count * 2))
            
            if !first {
                exp.fulfill()
            } else {
                first = false
            }
        }
        
        state.count = 1
        
        wait(for: [exp], timeout: 5)
    }
    
    func testCyclicGraphDependencyWhenComputedIsNotChanged() throws {
        // 1 - 2 - 3 - 1.
        // So:
        // 3 dep: [1, 2].
        // 2 dep: [1]
        // 1 dep: N/A (atom)
        let state = State()
        
        let computed = SwiftX.computed({
            return 0
        })
        
        let exp = expectation(description: "Should only update observer once no matter how many dependencies that has been updated")
        exp.assertForOverFulfill = true
        exp.expectedFulfillmentCount = 1
        
        var first = true
        autorun {
            print("[3] computed is \(computed.value) and count \(state.count)")
            
            if !first {
                exp.fulfill()
            } else {
                first = false
            }
        }
        
        state.count = 1
        
        wait(for: [exp], timeout: 5)
    }

    
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
    
    func testPredictability() {
        struct PState {
            @Observable var firstName = "Patrik"
            @Observable var lastName = "Karlsson"
        }
        let state = PState()
        let fullName = computed({ "\(state.firstName) \(state.lastName)"})
        
        let exp = expectation(description: "test")
        exp.assertForOverFulfill = true
        exp.expectedFulfillmentCount = 1
        reaction({ return fullName.value }, {
            XCTAssert($0 == "Patrik Larsson")
            exp.fulfill()
        })
        
        var count = 0
        autorun {
            if count == 0 {
                XCTAssert(fullName.value == "Patrik Karlsson")
            } else {
                XCTAssert(fullName.value == "Patrik Larsson")
            }
            count += 1
        }
        XCTAssert(fullName.value == "Patrik Karlsson")
        
        state.lastName = "Larsson"
        XCTAssert(fullName.value == "Patrik Larsson")
        wait(for: [exp], timeout: 1)
    }
}

private struct State {
    @Observable var count = 0
    @Observable var list = [Int]()
}
