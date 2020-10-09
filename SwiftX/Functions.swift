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
    
    internal var isObserving = false
    
    private var onCancelCallbacks = [OnCancelCallback]()
    private var cancellable: AnyCancellable?
    
    private var lock = os_unfair_lock_s()
    private let computeFunc: () -> V
    
    private var _value: V?
    public var value: V {
        get {
            willGetValue() // <--- adds observer to this if possible
            os_unfair_lock_lock(&lock)
            if _value == nil {
                // We should NOT add observer here, an observer that
                // wants to observe us should not start observing our
                // our dependencies..
                ObserverAdministrator.shared.runWithoutObserverContext {
                    _value = computeFunc()
                }
            }
            let value = _value!
            os_unfair_lock_unlock(&lock)
            return value
        }
    }
    
    public init(_ computeFunc: @escaping () -> V) {
        self.computeFunc = computeFunc
        ObserverAdministrator
            .shared
            .addReaction(observer: self, computeFunc)
        self.cancellable = AnyCancellable({ [weak self] in
            guard let self = self else { return }
            self.onCancelCallbacks.forEach({ $0(self) })
        })
    }
    
    deinit {
        cancellable?.cancel()
    }
}

extension Computed: IObservable { }
extension Computed: IObserver {
    func willUpdate() {
        // mark as stale is more efficient than counting dep's in admin?
        scheduleObserversForUpdate()
    }
    
    func updated() {
        //TODO: solve "re-adding" of "lost" observations.. Like we did for reactions.. (== ObserverContext)
        os_unfair_lock_lock(&self.lock)
        self._value = nil
        os_unfair_lock_unlock(&self.lock)
    }
    
    func cancel() {
        cancellable?.cancel()
    }
    
    func onCancel(_ closure: @escaping OnCancelCallback) {
        // TODO: might need to consider locking and not add if we'r cancelled...
        onCancelCallbacks.append(closure)
    }
}
