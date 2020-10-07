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

protocol IObservable: AnyObject {
    var observers: [ObjectIdentifier: IObserver] { get set }
    var observersLock: os_unfair_lock_s { get set }
}

extension IObservable {
    // TODO: rename
     func willGetValue() {
        if let obs = ObserverAdministrator.shared.currentObserverContext {
            os_unfair_lock_lock(&observersLock)
            observers[ObjectIdentifier(obs)] = obs
            obs.onCancel(remove)
            obs.isObserving = true
            #if DEBUG
            ReactionCyclicChangeDetector.shared.accessedObservable(ObjectIdentifier(self))
            #endif
            os_unfair_lock_unlock(&observersLock)
        }
    }
    
     func scheduleObserversForUpdate() {
        os_unfair_lock_lock(&observersLock)
        // Take copy to prevent deadlock between our lock and transactionLock..
        let observers = self.observers
        os_unfair_lock_unlock(&observersLock)
        ObserverAdministrator.shared.scheduleForUpdates(observers: observers)
        
        #if DEBUG
        ReactionCyclicChangeDetector.shared.didSetObservable(ObjectIdentifier(self))
        #endif
    }
    
     func remove(_ observer: IObserver) {
        os_unfair_lock_lock(&observersLock)
        observers[ObjectIdentifier(observer)] = nil
        // TODO:
        // what about the onCancel-callback?
        os_unfair_lock_unlock(&observersLock)
    }
}

// MARK: - PropertyWrapper

// Should IObserver contain its dependencies (Observables)?

@propertyWrapper public class Observable<Value>: IObservable {
    internal var observers = [ObjectIdentifier: IObserver]()
    internal var observersLock = os_unfair_lock_s()
    
    private var value: Value {
        didSet {
            ObserverAdministrator.shared.didUpdate(observable: self)
        }
    }
    
    public init(wrappedValue: Value) {
        self.value = wrappedValue
    }
    
    public var wrappedValue: Value {
        get {
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
