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
public func autorun(_ closure: @escaping () -> Void) -> AnyCancellable {
    reaction(closure, { })
}

// Desc, data should only access and return state derived data (@Observable props)
@discardableResult
public func reaction<V>(_ trackFunc: @escaping () -> V, _ onChange: @escaping (V) -> Void) -> AnyCancellable {
    let ctx = ObserverAdministrator.shared.addReaction(trackFunc, onChange)
    return ctx.cancellable
}

public func inTransaction(_ transaction: () -> Void) {
    ObserverAdministrator.shared.inTransaction(transaction)
}

public func computed<V>(_ computeClosure: @escaping () -> V) -> Computed<V> {
    Computed(computeClosure)
}

public final class Computed<V>: DynamicProperty {
    internal var observers = [ObjectIdentifier : IObserver]()
    internal var observersLock = os_unfair_lock_s()
    private var lock = os_unfair_lock_s()
    private let computeFunc: () -> V
    private var cancellable: AnyCancellable?
    
    private var _value: V?
    var value: V {
        get {
            willGetValue()
            os_unfair_lock_lock(&lock)
            if _value == nil {
                _value = computeFunc()
            }
            let value = _value!
            os_unfair_lock_unlock(&lock)
            return value
        }
    }
    
    init(_ computeFunc: @escaping () -> V) {
        self.computeFunc = computeFunc
        var first = true
        self.cancellable = ObserverAdministrator.shared.addReaction({
            if first {
                _ = computeFunc()
                first = false
            }
        }, {
            os_unfair_lock_lock(&self.lock)
            self._value = nil
            os_unfair_lock_unlock(&self.lock)
            self.didSetValue()
        }).cancellable
    }
    
    deinit {
        cancellable?.cancel()
    }
}

extension Computed: IObservable { }
