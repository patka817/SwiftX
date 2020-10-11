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
            obs.didAccess(observable: self)
            #if DEBUG
            ReactionCyclicChangeDetector.shared.accessedObservable(ObjectIdentifier(self))
            #endif
            os_unfair_lock_unlock(&observersLock)
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
            didSetValue()
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
