//
//  Computed.swift
//  SwiftX
//
//  Created by Patrik Karlsson on 2020-10-16.
//  Copyright © 2020 Patrik Karlsson. All rights reserved.
//

import Foundation
import Combine

public final class Computed<V> {
    final internal var observers = [ObjectIdentifier : IObserver]()
    final internal var observersLock = os_unfair_lock_s()
    
    final internal var isObserving = false
    final internal var observingObservablesLock = os_unfair_lock_s()
    final internal var observingObservables = [ObjectIdentifier: Weak<(IObservable)>]()
    final private var cancellable: AnyCancellable?
    final internal var _observablesAccessed = Set<ObjectIdentifier>()
    final internal var _isTrackingRemovals = false
    
    final private var lock = os_unfair_lock_s()
    final private let computeFunc: () -> V
    
    final private var _value: V?
    final public var value: V {
        get {
            willGetValue() // <--- adds observer to this if possible
            os_unfair_lock_lock(&lock)
            if _value == nil {
                // We should NOT add observer here, an observer that
                // wants to observe us should not start observing our
                // own dependencies..
                
                // BUT, to solve the issue with moved props we need to see that our observables (which we depend on)
                // are still the same or remove those we dont access anymore (or add those introduced now)
                
                // Finally, we should only track if we got observers
                // (so we dont start to track on "manual" get)
                os_unfair_lock_lock(&observersLock)
                let isBeingObserved = observers.isEmpty == false
                os_unfair_lock_unlock(&observersLock)
                
                if isBeingObserved {
                    ObserverAdministrator.shared.runWithoutObserverContext {
                        ObserverAdministrator.shared._currentObserverContext = self
                        startTrackingRemovals()
                        _value = computeFunc()
                        stopTrackingRemovals()
                        ObserverAdministrator.shared._currentObserverContext = nil
                    }
                } else {
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
        
        self.cancellable = AnyCancellable({ [weak self] in
            guard let self = self else { return }
            self.unobserveFromAllObservables()
        })
    }
    
    deinit {
        cancellable?.cancel()
    }
}

extension Computed: IObservable {
    final func onObserverCancelled(_ observer: IObserver) {
        os_unfair_lock_lock(&observersLock)
        observers[ObjectIdentifier(observer)] = nil
        if observers.isEmpty {
            unobserveFromAllObservables()
        }
        os_unfair_lock_unlock(&observersLock)
    }
}

extension Computed: IObserver {
    final func willUpdate() { // Always called inTransaction???? -> schedule can be made without the lock..
        scheduleObserversForUpdate()
    }
    
    final func updated() {
        os_unfair_lock_lock(&self.lock)
        self._value = nil
        os_unfair_lock_unlock(&self.lock)
    }
    
    final func cancel() {
        cancellable?.cancel()
    }
}
