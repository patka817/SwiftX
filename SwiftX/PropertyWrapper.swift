//
//  PropertyWrappers.swift
//  test
//
//  Created by Patrik Karlsson on 2020-10-05.
//  Copyright © 2020 Patrik Karlsson. All rights reserved.
//

import Foundation
import SwiftUI

// MARK: - PropertyWrapper

@propertyWrapper public final class Observable<Value>: IObservable {
    internal var observers = [ObjectIdentifier: IObserver]()
    internal var observersLock = os_unfair_lock_s()
    private let equal: ((Value, Value) -> Bool)?
    private var value: Value {
        didSet {
            didSetValue()
        }
    }
    
    public init(wrappedValue: Value) {
        self.value = wrappedValue
        self.equal = nil
    }
    
    public init(wrappedValue: Value) where Value: Equatable {
        self.value = wrappedValue
        self.equal = { $0 == $1 }
    }
    
    public init(from decoder: Decoder) throws where Value: Codable {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let value = try container.decode(Value.self, forKey: .wrappedValue)
        self.value = value
        self.equal = nil
    }
    
    public init(from decoder: Decoder) throws where Value: Codable & Equatable {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let value = try container.decode(Value.self, forKey: .wrappedValue)
        self.value = value
        self.equal = { $0 == $1 }
    }

    public var wrappedValue: Value {
        get {
            willGetValue()
            return value
        }
        set {
            if equal?(newValue, value) == true {
                #if DEBUG
                print("Saved an update")
                #endif
                return
            }
            value = newValue
        }
    }
    
    public var projectedValue: Binding<Value> {
        Binding(get: {
            self.wrappedValue
        }, set: { self.wrappedValue = $0 })
    }
}

extension Observable: Codable where Value: Codable {
    enum CodingKeys: String, CodingKey {
        case wrappedValue
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let value = wrappedValue
        try container.encode(value, forKey: .wrappedValue)
    }
}
