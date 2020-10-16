//
//  AccessEncoder.swift
//  SwiftX
//
//  Created by Patrik Karlsson on 2020-10-16.
//  Copyright © 2020 Patrik Karlsson. All rights reserved.
//

import Foundation

internal struct AccessEncoder {
    private let encoder = _AccessEncoder()
    
    init() { }
    
    func accessProperties<V: Encodable>(in value: V) throws {
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
