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
            if observers[ObjectIdentifier(obs)] == nil {
                observers[ObjectIdentifier(obs)] = obs
                obs.onCancel(onObserverCancelled)
                obs.isObserving = true
            }
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

     func onObserverCancelled(_ observer: IObserver) {
        os_unfair_lock_lock(&observersLock)
        observers[ObjectIdentifier(observer)] = nil
        os_unfair_lock_unlock(&observersLock)
    }

    func removeAllObservers() {
        os_unfair_lock_lock(&observersLock)
        observers = [:]
        os_unfair_lock_unlock(&observersLock)
    }
}

// MARK: - PropertyWrapper

// Should IObserver contain its dependencies (Observables)?

@propertyWrapper public class Observable<Value>: IObservable {
    // TODO: should really make observers weak???!!!!!! Got retain cycle now..??
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

    deinit {
        print("deiniting, got \(observers.count) observers")

    }
    
    public var wrappedValue: Value {
        get {
            willGetValue()
            return value
        }
        set {
            if let value = value as? IObservable {
                print("Old value have \(value.observers.count) observers")
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
