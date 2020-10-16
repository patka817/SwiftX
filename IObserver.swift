//
//  IObserver.swift
//  SwiftX
//
//  Created by Patrik Karlsson on 2020-10-16.
//  Copyright © 2020 Patrik Karlsson. All rights reserved.
//

import Foundation

internal protocol IObserver: AnyObject {
    var observingObservablesLock: os_unfair_lock_s { get set }
    var observingObservables: [ObjectIdentifier: Weak<IObservable>] { get set }
    var isObserving: Bool { get set }
    
    var _isTrackingRemovals: Bool { get set }
    var _observablesAccessed: Set<ObjectIdentifier> { get set }
    
    /// Is always run inside the transaction lock.
    func didAccess(observable: IObservable)
    
    /// Is called before the update-loop will start.
    /// Is always run inside the transaction lock.
    func willUpdate()
    
    /// Is always run inside the transaction lock.
    func updated()
    func cancel()
}

extension IObserver {
    func startTrackingRemovals() {
        _isTrackingRemovals = true
    }

    func stopTrackingRemovals() {
        _isTrackingRemovals = false
        os_unfair_lock_lock(&observingObservablesLock)
        observingObservables = observingObservables.filter({
            if _observablesAccessed.contains($0.key) == false {
                $0.value.value?.onObserverCancelled(self)
                return false
            }
            return true
        })
        os_unfair_lock_unlock(&observingObservablesLock)
        _observablesAccessed.removeAll()
    }

    func didAccess(observable: IObservable) {
        let id = ObjectIdentifier(observable)
        os_unfair_lock_lock(&observingObservablesLock)
        if observingObservables[id] == nil {
            observingObservables[id] = Weak(observable)
        }
        os_unfair_lock_unlock(&observingObservablesLock)
        if _isTrackingRemovals {
            _observablesAccessed.insert(id)
        }
        isObserving = true
    }
    
    func unobserveFromAllObservables() {
        os_unfair_lock_lock(&observingObservablesLock)
        observingObservables = observingObservables.filter({
            $0.value.value?.onObserverCancelled(self)
            return false
        })
        os_unfair_lock_unlock(&observingObservablesLock)
    }
    
}
