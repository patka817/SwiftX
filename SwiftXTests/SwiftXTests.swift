//
//  SwiftXTests.swift
//  testTests
//
//  Created by Patrik Karlsson on 2020-10-06.
//  Copyright © 2020 Patrik Karlsson. All rights reserved.
//

import XCTest
import SwiftX

class SwiftXTests: XCTestCase {
    var state: AppState!
    
    override func setUp() {
        state = AppState()
    }

    func testTest() {
        class Inner {
            @Observable var price = 0
        }

        class Outer {
            @Observable var inner = Inner()
        }

        let outer = Outer()

        var exp = expectation(description: "")
        exp.expectedFulfillmentCount = 2

        var read: Int?
        let token = autorun {
            print("PRICE IS \(outer.inner.price)")
            read = outer.inner.price
            exp.fulfill()
        }

        outer.inner.price = 666

        wait(for: [exp], timeout: 1)
        XCTAssert(read! == outer.inner.price)

        exp = expectation(description: "")


        outer.inner = {
            let inner = Inner()
            inner.price = -100
            return inner
        }()

        wait(for: [exp], timeout: 100)
        XCTAssert(read! == outer.inner.price)

//        token.cancel()

//        let exp2 = expectation(description: "")
//        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
//            outer.inner.price = -666
//            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
//                exp2.fulfill()
//            }
//        }
//        wait(for: [exp2], timeout: 5)
    }

    func testCyclicGraphDependency() throws {
        // 1 - 2 - 3 - 1.
        // So:
        // 3 dep: [1, 2].
        // 2 dep: [1]
        // 1 dep: N/A (atom)
        
        let computed = SwiftX.computed({
            print("Computed count: \(self.state.count)")
        })
        
        let exp = expectation(description: "Should only update observer once no matter how many dependencies that has been updated")
        exp.assertForOverFulfill = true
        exp.expectedFulfillmentCount = 1
        
        var first = true
        autorun {
            print("[3] computed is \(computed.value) and count \(self.state.count)")
            if !first {
                exp.fulfill()
            } else {
                first = false
            }
        }
        
        state.count = 1
        
        wait(for: [exp], timeout: 5)
    }

    func testUpdateOneValueInLongChainOfDep() {
        var comps = [Computed<Int>]()
        var compFunc: () -> Int = { self.state.count }
        for _ in 1...20 {
            let comp = Computed(compFunc)
            comps.append(comp)
            compFunc = { comp.value }
        }
        
        let exp = expectation(description: "Should reach last fast")
        exp.assertForOverFulfill = true
        reaction(compFunc, {
            print("last comp: \($0)")
            exp.fulfill()
        })
        
        inTransaction {
            state.count = 4
        }
        
        wait(for: [exp], timeout: 5)
        
    }
    
    func testPerfomanceUpdateOneValueInLongChainOfDep() {
        var comps = [Computed<Int>]()
        var compFunc: () -> Int = { self.state.count }
        for _ in 1...20 {
            let comp = Computed(compFunc)
            comps.append(comp)
            compFunc = { comp.value }
        }
        
        var exp: XCTestExpectation?
        reaction(compFunc, {
            print("last comp: \($0)")
            exp?.fulfill()
        })
        
        measure {
            exp = expectation(description: "Should reach last fast")
            exp?.assertForOverFulfill = true
            inTransaction {
                state.count = 4
            }
            wait(for: [exp!], timeout: 5)
        }
    }

}

class AppState {
    @Observable var greeting = "Hej"
    @Observable var count = 0
    @Observable var mainContentGreeting = "Hello counter world"
    @Observable var nilable: String? = nil
    @Observable var testTrigger = false
    
    private var _id: ObjectIdentifier?
    var id: ObjectIdentifier {
        if _id == nil {
            _id = ObjectIdentifier(self)
        }
        return _id!
    }
}
