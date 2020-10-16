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
    
    // TODO: MOVE CODABLE / ACCESS TESTS TO SEPERATE FILE
    
    func testAccessPerfomance() {
        class Pirate: Codable {
            @Observable var greeting = "Arr!"
            @Observable var legs = 2
            @Observable var children = [Pirate]()
        }
        
        var pirate = Pirate()
        for i in 1...50 {
            let child = Pirate()
            child.greeting = "oh-hoy"
            child.legs = i
            pirate.children.append(child)
            if [10, 20, 30, 40].contains(i) {
                pirate = child
            }
        }
        measure {
            try! AccessEncoder().accessProperties(in: pirate)
        }
    }
    
    func testJSONPerfomance() {
        class Pirate: Codable {
            @Observable var greeting = "Arr!"
            @Observable var legs = 2
            @Observable var children = [Pirate]()
        }
        
        var pirate = Pirate()
        for i in 1...50 {
            let child = Pirate()
            child.greeting = "oh-hoy"
            child.legs = i
            pirate.children.append(child)
            if [10, 20, 30, 40].contains(i) {
                pirate = child
            }
        }
        measure {
            _ = try! JSONEncoder().encode(pirate)
        }
    }
    
    func testAccessEncoder() {
        class Pirate: Codable {
            @Observable var greeting = "Arr!"
            @Observable var legs = 2
            @Observable var children = [Pirate]()
        }
        
        let pirate = Pirate()
        let child = Pirate()
        child.greeting = "oh-hoy"
        child.legs = 44
        pirate.children.append(child)
        
        try! AccessEncoder().accessProperties(in: pirate)
    }
    
    func testCodable() {
        class Pirate: Codable {
            @Observable var greeting = "Arr!"
            @Observable var legs = 2
            @Observable var children = [Pirate]()
        }
        
        let pirate = Pirate()
        pirate.children.append(Pirate())
        
        let json = try! JSONEncoder().encode(pirate)        
        let copyPirate = try! JSONDecoder().decode(Pirate.self, from: json)
        
        let exp = expectation(description: "")
        exp.expectedFulfillmentCount = 2
        autorun {
            copyPirate.children.forEach({
                print("\($0.greeting)")
            })
            exp.fulfill()
        }
        
        copyPirate.children.first?.greeting = "Oooofy"
        
        wait(for: [exp], timeout: 1)
    }
    
    func testObserveWholeGraph() {
        class Pirate: Codable {
            @Observable var greeting = "Arr!"
            @Observable var legs = 2
            @Observable var children = [Pirate]()
        }
        let mainPirate = Pirate()
        var pirate = mainPirate
        var deepChildrens = [Pirate]()
        for i in 1...50 {
            let child = Pirate()
            child.greeting = "oh-hoy"
            child.legs = i
            pirate.children.append(child)
            if [10, 20, 30, 40].contains(i) {
                deepChildrens.append(child)
                pirate = child
            }
        }
        
        // TODO: tests for removing, adding etc..
        
        let exp = expectation(description: "")
        exp.expectedFulfillmentCount = 2
        let access = AccessEncoder()
        reaction({
            try! access.accessProperties(in: mainPirate)
        }, {
            exp.fulfill()
            print("Changed pirate!")
        })
        
        reaction({
            deepChildrens[2].greeting
        }, {
            print("Got greeting \($0)")
            exp.fulfill()
        })
        
        deepChildrens[2].greeting = "Woohoo"
        
        wait(for: [exp], timeout: 1)
    }
    
    // ----------------------------
    
    func testOrderOfExecutionAndEnsureOneRunOnly() {
        // Create dep. graph like:
        // firstName <-- [autorun, fullname]
        // lastName <-- [fullName]
        // fullName <-- [autorun]
        struct Person {
            @Observable var firstName = ""
            @Observable var lastName = ""
            var fullName: Computed<String>!
            
            internal init() {
                self.fullName = Computed({ [self] in
                    print("COMPUTING")
                    return "\(self.firstName) \(self.lastName)"
                })
            }
        }
        
        let person = Person()
        person.firstName = "Kalle"
        person.lastName = "Anka"
        
        var exp = expectation(description: "")
        autorun {
            print("firstname is \(person.firstName)")
            print("fullname is \(person.fullName.value)")
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 1)
        
        exp = expectation(description: "")
        exp.expectedFulfillmentCount = 1
        exp.assertForOverFulfill = true
        person.firstName = "Fnatte"
        wait(for: [exp], timeout: 1)
    }
    
    func testConditionalObservingAutorun() {
        struct MessagePrint {
            @Observable var print = true
            @Observable var message: String?
        }
        let msgPrint = MessagePrint()
        
        var exp = expectation(description: "")
        exp.expectedFulfillmentCount = 2
        var lastPrintedMessage: String? = nil
        autorun {
            if msgPrint.print {
                lastPrintedMessage = msgPrint.message
                print(msgPrint.message)
            }
            exp.fulfill()
        }
        
        msgPrint.message = "hej"
        wait(for: [exp], timeout: 1)
        XCTAssert(lastPrintedMessage == msgPrint.message)
        
        exp = expectation(description: "")
        msgPrint.print = false
        wait(for: [exp], timeout: 1)
        XCTAssert(lastPrintedMessage == "hej")
        
        // Verify that we are cut of the branch with (== not observing) message-observable
        exp = expectation(description: "")
        exp.isInverted = true
        msgPrint.message = "Hello, world!"
        wait(for: [exp], timeout: 1)
        XCTAssert(lastPrintedMessage == "hej")
    }
    
    func testMoveObservedPropertyWrapper() {
        let parent = Node()
        var exp = expectation(description: "")
        exp.expectedFulfillmentCount = 2
        autorun {
            print("left value is \(String(describing: parent.left?.value))")
            exp.fulfill()
        }
        
        let leftChild = Node()
        parent.left = leftChild
        
        wait(for: [exp], timeout: 1)
        
        exp = expectation(description: "")
        exp.expectedFulfillmentCount = 1
        
        inTransaction {
            parent.right = parent.left
            parent.left = nil
        }
        wait(for: [exp], timeout: 1)
        
        exp = expectation(description: "")
        exp.isInverted = true
        parent.right?.value = "tjillivippen"
        
        wait(for: [exp], timeout: 1)
    }
    
    func disabled_testCyclicDependencyDetector() {
        autorun {
            _ = self.state.count
            self.state.count = 1
        }
    }
    
    func testSettingStateInReaction() {
        let exp = expectation(description: "")
        exp.expectedFulfillmentCount = 2
        reaction({
            self.state.count
        }, {
            print("Got state \($0)")
            self.state.greeting = "\($0)"
        })
        
        reaction({
            self.state.greeting
        }, {
            print("Got greeting " + $0)
            exp.fulfill()
        })
        
        state.greeting = "Zerooooo"
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(100), execute: { self.state.count = 100 })
    
        wait(for: [exp], timeout: 1)
        XCTAssert(state.greeting == "100")
    }
    
    func testSettingStateInAutorun() {
        let parent = Node()
        parent.value = "Hej"
        let exp = expectation(description: "")
        exp.expectedFulfillmentCount = 3
        
        var parentValueSeen: String?
        autorun {
            print("***** AUTORUN ACCESSING PARENT:VALUE *******")
            print(parent.value)
            parentValueSeen = parent.value
            exp.fulfill()
        }
        
        autorun {
            print("***** AUTORUN READING LEFT.VALUE AND SETTING PARENT.VALUE ******")
            print("left has value: \(parent.left?.value ?? "nil")")
            parent.value = parent.left?.value ?? "nil"
        }
    
        let l = Node()
        l.value = "Lefty"
        parent.left = l
        
        wait(for: [exp], timeout: 1)
        XCTAssert(parentValueSeen == (parent.left?.value ?? ""))
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
    
    func testUpdateReferenceType() {
        let wrappedState = StateWrapper()
        
        var exp = expectation(description: "Should get new state")
        var recValue: Int?
        reaction({ wrappedState.state }, {
            print("Got substate with count \($0.count)")
            recValue = $0.count
            exp.fulfill()
        })
        
        let new = AppState()
        new.count = 666
        wrappedState.state = new
        
        wait(for: [exp], timeout: 1)
        
        exp = expectation(description: "Should get new state")
        wrappedState.state.count = 1000
        
        wait(for: [exp], timeout: 1)
        XCTAssert(recValue == new.count)
    }
    
    func testUpdateSubReferenceTypeAndListenToSubReferenceObservableValue() {
        let wrappedState = StateWrapper()
        wrappedState.state.count = 1000
        
        var exp = expectation(description: "Should get new state")
        var recValue: Int?
        
        reaction({ wrappedState.state.count }, {
            recValue = $0
            exp.fulfill()
        })
        
        let new = AppState()
        new.count = 666
        wrappedState.state = new
        
        wait(for: [exp], timeout: 1)
        XCTAssert(recValue == new.count, "Should get updated count since we access count through the wrappedState (making autorun observable to both state and count)")
        
        exp = expectation(description: "Waiting for -1..")
        wrappedState.state.count = -1
        
        wait(for: [exp], timeout: 1)
        XCTAssert(recValue == -1, "Failed to get updated count after setting new reference-object :(")
    }

    func testUpdateOneValueTypeInLongChainOfDep() {
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
    
    func testPerfomanceUpdateOneValueTypeInLongChainOfDep() {
        var comps = [Computed<Int>]()
        var compFunc: () -> Int = { self.state.count }
        for _ in 1...100 {
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
            let newValue = Int.random(in: 0...100)
            state.count = newValue
            wait(for: [exp!], timeout: 5)
            XCTAssert(comps.last!.value == newValue)
        }
    }

}

struct StateWrapper {
    @Observable var state = AppState()
}

class AppState {
    @Observable var greeting = "Hej"
    @Observable var count = 0
    @Observable var mainContentGreeting = "Hello counter world"
    @Observable var nilable: String? = nil
    @Observable var testTrigger = false
    
    @Observable var arr = [1, 2]
    
    private var _id: ObjectIdentifier?
    var id: ObjectIdentifier {
        if _id == nil {
            _id = ObjectIdentifier(self)
        }
        return _id!
    }
}

class Node {
    @Observable var left: Node?
    @Observable var right: Node?
    @Observable var value = ""
}
