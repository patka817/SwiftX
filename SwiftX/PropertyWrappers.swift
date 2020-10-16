//
//  PropertyWrappers.swift
//  test
//
//  Created by Patrik Karlsson on 2020-10-05.
//  Copyright © 2020 Patrik Karlsson. All rights reserved.
//

import Foundation
import SwiftUI
import Combine

struct Weak<T> {
    private weak var _value: AnyObject?
    var value: T? {
        get { _value as? T }
        set { _value = newValue as AnyObject }
    }
    
    init(_ value: T) {
        self.value = value
    }
}

protocol IObservable: AnyObject {
    var observers: [ObjectIdentifier: IObserver] { get set }
    var observersLock: os_unfair_lock_s { get set }
    
    func onObserverCancelled(_ observer: IObserver)
}

extension IObservable {
    // TODO: rename? or not..
     func willGetValue() {
        if let obs = ObserverAdministrator.shared.currentObserverContext {
            os_unfair_lock_lock(&observersLock)
            observers[ObjectIdentifier(obs)] = obs
            os_unfair_lock_unlock(&observersLock)
            obs.didAccess(observable: self)
            #if DEBUG
            ReactionCyclicChangeDetector.current.accessedObservable(ObjectIdentifier(self))
            #endif
        }
    }
    
    func didSetValue() {
        ObserverAdministrator.shared.didUpdate(observable: self)
    }
    
     func scheduleObserversForUpdate() {
        os_unfair_lock_lock(&observersLock)
        // Take copy to prevent deadlock between our lock and transactionLock..
        let observers = self.observers
        os_unfair_lock_unlock(&observersLock)
        ObserverAdministrator.shared.scheduleForUpdates(observers: observers)
    }

     func onObserverCancelled(_ observer: IObserver) {
        os_unfair_lock_lock(&observersLock)
        observers[ObjectIdentifier(observer)] = nil
        os_unfair_lock_unlock(&observersLock)
    }
}

// MARK: - PropertyWrapper

// Should IObserver contain its dependencies (Observables)?

@propertyWrapper public final class Observable<Value>: IObservable {
    internal var observers = [ObjectIdentifier: IObserver]()
    internal var observersLock = os_unfair_lock_s()
    
    private var value: Value {
        didSet {
            didSetValue()
        }
    }
    
    public init(wrappedValue: Value) {
        self.value = wrappedValue
    }
    
    public init(from decoder: Decoder) throws where Value: Codable {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let value = try container.decode(Value.self, forKey: .wrappedValue)
        self.value = value
    }

    deinit {
        print("deiniting, got \(observers.count) observers")

    }
    
    public var wrappedValue: Value {
        get {
            print("GET \(value)")
            willGetValue()
            return value
        }
        set {
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

// --------- TODO MOVE ------------

// TODO: Internal. We should expose a function for observing a whole object-graph.
public struct AccessEncoder {
    private let encoder = _AccessEncoder()
    
    public init() { }
    
    public func accessProperties<V: Encodable>(in value: V) throws {
        try value.encode(to: encoder)
    }
}

fileprivate struct _AccessEncoder: Encoder {
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey : Any] = [:]
    
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        KeyedEncodingContainer(AccessKeyedContainer(encoder: self))
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        AccessUnkeyedContainer(encoder: self)
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        AccessUnkeyedContainer(encoder: self)
    }
}

fileprivate struct AccessKeyedContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    var encoder: _AccessEncoder
    var codingPath: [CodingKey] = []
    
    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        encoder.container(keyedBy: keyType)
    }
    
    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        encoder.unkeyedContainer()
    }
    
    mutating func superEncoder() -> Encoder {
        encoder
    }
    
    mutating func superEncoder(forKey key: Key) -> Encoder {
        encoder
    }
    
    mutating func encodeNil(forKey key: Key) throws { }
    public mutating func encode(_ value: Bool, forKey key: Key) throws { }
    public mutating func encode(_ value: Int, forKey key: Key) throws { }
    public mutating func encode(_ value: Int8, forKey key: Key) throws { }
    public mutating func encode(_ value: Int16, forKey key: Key) throws { }
    public mutating func encode(_ value: Int32, forKey key: Key) throws { }
    public mutating func encode(_ value: Int64, forKey key: Key) throws { }
    public mutating func encode(_ value: UInt, forKey key: Key) throws { }
    public mutating func encode(_ value: UInt8, forKey key: Key) throws { }
    public mutating func encode(_ value: UInt16, forKey key: Key) throws { }
    public mutating func encode(_ value: UInt32, forKey key: Key) throws { }
    public mutating func encode(_ value: UInt64, forKey key: Key) throws { }
    public mutating func encode(_ value: Float, forKey key: Key) throws { }
    public mutating func encode(_ value: Double, forKey key: Key) throws { }
    public mutating func encode(_ value: String, forKey key: Key) throws { }
    public mutating func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
        try value.encode(to: encoder)
    }
}

fileprivate struct AccessUnkeyedContainer: UnkeyedEncodingContainer, SingleValueEncodingContainer {
    var encoder: _AccessEncoder
    var codingPath: [CodingKey] = []
    var count: Int = 0
    
    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        encoder.container(keyedBy: keyType)
    }
    
    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        encoder.unkeyedContainer()
    }
    
    mutating func superEncoder() -> Encoder {
        encoder
    }
    
    mutating func encodeNil() throws { }
    public mutating func encode(_ value: Bool) throws { }
    public mutating func encode(_ value: Int) throws { }
    public mutating func encode(_ value: Int8) throws { }
    public mutating func encode(_ value: Int16) throws { }
    public mutating func encode(_ value: Int32) throws { }
    public mutating func encode(_ value: Int64) throws { }
    public mutating func encode(_ value: UInt) throws { }
    public mutating func encode(_ value: UInt8) throws { }
    public mutating func encode(_ value: UInt16) throws { }
    public mutating func encode(_ value: UInt32) throws { }
    public mutating func encode(_ value: UInt64) throws { }
    public mutating func encode(_ value: Float) throws { }
    public mutating func encode(_ value: Double) throws { }
    public mutating func encode(_ value: String) throws { }
    public mutating func encode<T>(_ value: T) throws where T : Encodable {
        try value.encode(to: encoder)
    }
}
