//
//  IObservable.swift
//  SwiftX
//
//  Created by Patrik Karlsson on 2020-10-16.
//  Copyright © 2020 Patrik Karlsson. All rights reserved.
//

import Foundation

internal protocol IObservable: AnyObject {
    var observers: [ObjectIdentifier: IObserver] { get set }
    var observersLock: os_unfair_lock_s { get set }
    
    func onObserverCancelled(_ observer: IObserver)
}

internal extension IObservable {
    // TODO: rename? or not..
     func willGetValue() {
        if let obs = ObserverAdministrator.shared.currentObserverContext {
            os_unfair_lock_lock(&observersLock)
            observers[ObjectIdentifier(obs)] = obs
            os_unfair_lock_unlock(&observersLock)
            obs.didAccess(observable: self)
            #if DEBUG
            ReactionCyclicChangeDetector.current.accessedObservable(ObjectIdentifier(self))
            #endif
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
}
