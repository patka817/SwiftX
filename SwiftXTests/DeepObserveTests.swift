//
//  DeepObserveTests.swift
//  SwiftXTests
//
//  Created by Patrik Karlsson on 2020-10-16.
//  Copyright © 2020 Patrik Karlsson. All rights reserved.
//

import XCTest
@testable import SwiftX

class DeepObserveTests: XCTestCase {

    func testAccessPerfomance() {
        let (pirate, _, _) = createPirateGraph(depth: 500)
        measure {
            try! AccessEncoder().accessProperties(in: pirate)
        }
    }
    
    func testDeepObservePerformance() {
        let (pirate, _, deepCrews) = createPirateGraph(depth: 500)
        measure {
            let cancel = deepObserve(pirate, {
                _ = pirate.legs
            })
            deepCrews.last?.crew.last?.legs = 1
            cancel.cancel()
        }
    }
    
    func testJSONPerfomance() {
        let (pirate, _, _) = createPirateGraph()
        measure {
            _ = try! JSONEncoder().encode(pirate)
        }
    }
    
    func testAccessEncoder() {
        let pirate = Pirate()
        let child = Pirate()
        child.greeting = "oh-hoy"
        child.legs = 44
        pirate.children.append(child)
        
        try! AccessEncoder().accessProperties(in: pirate)
    }
    
    func testCodable() {
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
        let (pirate, deepChildren, deepCrews) = createPirateGraph()
        
        // TODO: tests for removing, adding etc..
        
        let exp = expectation(description: "")
        exp.expectedFulfillmentCount = 3
        deepObserve(pirate, {
            exp.fulfill()
            print("Changed pirate!")
        })
        
        reaction({
            deepChildren[2].greeting
        }, {
            print("Got greeting \($0)")
            exp.fulfill()
        })
        
        deepChildren[2].greeting = "Woohoo"
        deepCrews.last!.legs = -1
        
        wait(for: [exp], timeout: 1)
    }
    
    func testEqualityCheckPerf() {
        measure {
            let pirate = Pirate()
            pirate.greeting = "HEJ"
            let exp = expectation(description: "")
            reaction({ pirate.greeting }, {
                exp.fulfill()
            })
            pirate.greeting = "HEJ"
            pirate.greeting = "1234"
            wait(for: [exp], timeout: 1)
        }
    }
    
    private func createPirateGraph(depth: Int = 50) -> (pirate: Pirate, deepChildren: [Pirate], deepCrew: [Pirate]) {
        let mainPirate = Pirate()
        var pirate = mainPirate
        var deepChildren = [Pirate]()
        for i in 1...depth {
            let child = Pirate()
            child.greeting = "oh-hoy"
            child.legs = i
            pirate.children.append(child)
            if [10, 20, 30, 40].contains(i) {
                deepChildren.append(child)
                pirate = child
            }
        }
        
        pirate = mainPirate
        var deepCrew = [Pirate]()
        for i in 1...depth {
            let crew = Pirate()
            crew.greeting = "crowdo"
            crew.legs = i
            pirate.crew.append(crew)
            if [10, 20, 30, 40].contains(i) {
                pirate = crew
                deepCrew.append(crew)
            }
        }
        
        return (mainPirate, deepChildren, deepCrew)
    }

}

class Pirate: Codable, Equatable {
    static func == (lhs: Pirate, rhs: Pirate) -> Bool {
        lhs.children == rhs.children &&
            lhs.greeting == rhs.greeting &&
            lhs.legs == rhs.legs &&
            lhs.crew == rhs.crew
    }
    
    @Observable var greeting = "Arr!"
    @Observable var legs = 2
    @Observable var children = [Pirate]()
    var crew = [Pirate]()
}
