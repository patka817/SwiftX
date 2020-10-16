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
    internal var observers = [ObjectIdentifier : IObserver]()
    internal var observersLock = os_unfair_lock_s()
    
    internal var isObserving = false
    internal var observingObservablesLock = os_unfair_lock_s()
    internal var observingObservables = [ObjectIdentifier: Weak<(IObservable)>]()
    private var cancellable: AnyCancellable?
    internal var _observablesAccessed = Set<ObjectIdentifier>()
    internal var _isTrackingRemovals = false
    
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
    func onObserverCancelled(_ observer: IObserver) {
        os_unfair_lock_lock(&observersLock)
        observers[ObjectIdentifier(observer)] = nil
        if observers.isEmpty {
            print("Unobserving all observables, not being observed anymore!")
            unobserveFromAllObservables()
        }
        os_unfair_lock_unlock(&observersLock)
    }
}

extension Computed: IObserver {
    func willUpdate() { // Always called inTransaction???? -> schedule can be made without the lock..
        scheduleObserversForUpdate()
    }
    
    func updated() {
        os_unfair_lock_lock(&self.lock)
        self._value = nil
        os_unfair_lock_unlock(&self.lock)
    }
    
    func cancel() {
        cancellable?.cancel()
    }
}
