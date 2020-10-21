//
//  Functions.swift
//  test
//
//  Created by Patrik Karlsson on 2020-10-05.
//  Copyright © 2020 Patrik Karlsson. All rights reserved.
//

import Foundation
import Combine
import SwiftUI

@discardableResult
public func autorun(named name: String? = nil, _ closure: @escaping () -> Void) -> AnyCancellable {
    reaction(named: name, closure, { })
}

// Desc, data should only access and return state derived data (@Observable props)
@discardableResult
public func reaction<V>(named name: String? = nil, _ trackFunc: @escaping () -> V, _ onChange: @escaping (V) -> Void) -> AnyCancellable {
    let ctx = ObserverAdministrator.shared.addReaction(named: name, trackFunc, onChange)
    return ctx.cancellable
}

public func inTransaction(_ transaction: () -> Void) {
    ObserverAdministrator.shared.inTransaction(transaction)
}

public func computed<V>(_ computeClosure: @escaping () -> V) -> Computed<V> {
    Computed(computeClosure)
}

@discardableResult
public func deepObserve<Object: Codable>(_ object: Object, _ onChange: @escaping () -> Void) -> AnyCancellable {
    let encoder = AccessEncoder()
    return reaction({
        try? encoder.accessProperties(in: object)
    }, onChange)
}

@discardableResult
public func encodeOnChange<Object: Codable, E: TopLevelEncoder>(object: Object, encoder: E, _ onEncoded: @escaping (Result<E.Output, Error>) -> Void) -> AnyCancellable {
    reaction({
        do {
            let data = try encoder.encode(object)
            return .success(data)
        } catch {
            return .failure(error)
        }
    }, onEncoded)
}
