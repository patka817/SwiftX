//
//  CollectionTests.swift
//  SwiftXTests
//
//  Created by Patrik Karlsson on 2020-10-12.
//  Copyright © 2020 Patrik Karlsson. All rights reserved.
//

import XCTest
import SwiftX

class CollectionTests: XCTestCase {
    func testDictionaryObservableRemove() {
        struct T {
            @Observable var dictionary = [String: Int]()
        }
        let t = T()
        t.dictionary["1"] = 55
        t.dictionary["2"] = -66
        
        let exp = expectation(description: "")
        exp.expectedFulfillmentCount = 2
        var recValue: [String: Int]?
        autorun {
            print("T.dictionary: \(t.dictionary)")
            recValue = t.dictionary
            exp.fulfill()
        }
        
        t.dictionary["2"] = nil
        wait(for: [exp], timeout: 1)
        XCTAssert(recValue == t.dictionary)
    }
    
    func testDictionaryObservableInsert() {
        struct T {
            @Observable var dictionary = [String: Int]()
        }
        let t = T()
        
        let exp = expectation(description: "")
        exp.expectedFulfillmentCount = 3
        var recValue: [String: Int]?
        autorun {
            print("T.dictionary: \(t.dictionary)")
            recValue = t.dictionary
            exp.fulfill()
        }
        
        t.dictionary["Hej"] = 55
        t.dictionary["Oh no"] = -66
        wait(for: [exp], timeout: 1)
        XCTAssert(recValue == t.dictionary)
    }
    
    func testSetObservable() {
        struct T {
            @Observable var set = Set<Int>()
        }
        let t = T()
        
        let exp = expectation(description: "")
        exp.expectedFulfillmentCount = 2
        var recValue: Set<Int>?
        autorun {
            print("T.set: \(t.set)")
            recValue = t.set
            exp.fulfill()
        }
        
        t.set.insert(60)
        wait(for: [exp], timeout: 1)
        XCTAssert(recValue == t.set)
    }
    
    func testArrayObservable() {
        struct T {
            @Observable var array = [Int]()
        }
        let t = T()
        
        let exp = expectation(description: "")
        exp.expectedFulfillmentCount = 2
        var recValue: [Int]?
        autorun {
            print("T.array: \(t.array)")
            recValue = t.array
            exp.fulfill()
        }
        
        
        t.array.append(1)
        wait(for: [exp], timeout: 1)
        XCTAssert(recValue == t.array)
    }
    
    func testCollectionObservableMap() {
        struct T {
            @Observable var array = [Int]()
            @Observable var set = Set<Int>()
            @Observable var dictionary = [String: Int]()
        }
        let t = T()
        
        let exp = expectation(description: "")
        exp.expectedFulfillmentCount = 6
        autorun {
            print("T.array*2: \(t.array.map({ $0*2 }))")
            exp.fulfill()
        }
        autorun {
            print("T.set*2: \(t.set.map({ $0*2 }))")
            exp.fulfill()
        }
        autorun {
            print("T.dict.values*2: \(t.dictionary.values.map({ $0*2 }))")
            exp.fulfill()
        }
        
        inTransaction {
            t.array.append(contentsOf: [1, 2, 3, 4, 5])
            t.set.insert(5)
            t.set.insert(10)
            t.set.insert(15)
            t.dictionary.merge(["1": 10, "2": 20, "3": 30], uniquingKeysWith: { f, _ in f })
        }
        
        wait(for: [exp], timeout: 1)
    }

}
