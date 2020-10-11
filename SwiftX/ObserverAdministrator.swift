//
//  ObserverAdministrator.swift
//  test
//
//  Created by Patrik Karlsson on 2020-10-05.
//  Copyright © 2020 Patrik Karlsson. All rights reserved.
//

import Foundation

final internal class ObserverAdministrator {
    static let shared = ObserverAdministrator()
    
    private var transactionLock = MutexLock(type: .recursive)
    private var _inTransaction = false
    private var pendingUpdatesDependencyCount = [ObjectIdentifier: Int]()
    private var pendingUpdateList = [IObserver]()
    private var updatedObservables = [ObjectIdentifier: IObservable]()
    private var _hasScheduled = false
    
    internal var currentObserverContext: IObserver? {
        get {
            transactionLock.inLock {
                return _currentObserverContext
            }
        }
    }
    internal var _currentObserverContext: IObserver?
    
    private init() { }
    
    func addReaction<V>(_ trackFunc: @escaping () -> V, _ onChange: @escaping (V) -> Void) -> ObserverContext {
        let ctx = ObserverContext(closure: { ourSelf in
            // if we run this in a context, we get re-added as observer for "lost" props
            // We remove ourself from those we have accessed but aren't accessing in this run.
            // (we are always run inside an update-loop, hence no need for locking)
            let prevCtx = self._currentObserverContext
            self._currentObserverContext = ourSelf
            ourSelf.startTrackingRemovals()
            let dataInput = trackFunc()
            ourSelf.stopTrackingRemovals()
            onChange(dataInput)

            self._currentObserverContext = prevCtx
        })
        addReaction(observer: ctx, trackFunc)
        return ctx
    }
    
    func addReaction<V, O: IObserver>(observer: O, _ trackFunc: @escaping () -> V) {
        transactionLock.lock()
        #if DEBUG
        ReactionCyclicChangeDetector.shared.clear()
        #endif
        let prevCtx = _currentObserverContext
        
        _currentObserverContext = observer
        _ = trackFunc()
        _currentObserverContext = prevCtx
        
        #if DEBUG
        assert(ReactionCyclicChangeDetector.shared.isCyclic == false, "Setting and getting the same property in a reaction is not allowed and will create an infinite loop")
        ReactionCyclicChangeDetector.shared.clear()
        #endif
        
        transactionLock.unlock()
        
        assert(observer.isObserving, "ERROR Adding reaction but not observing changes!")
    }
    
    // To prevent adding new observers for Computed observables..
    // (Maybe Computed --> derivation?)
    func runWithoutObserverContext<V>(_ closure: () -> V) -> V {
        transactionLock.lock()
        let ctx = _currentObserverContext
        _currentObserverContext = nil
        let value = closure()
        _currentObserverContext = ctx
        transactionLock.unlock()
        return value
    }
    
    func inTransaction<V>(_ transaction: () -> V) -> V {
        transactionLock.inLock {
            let isFirstTransaction = _inTransaction == false
            _inTransaction = true
            
            let value = transaction()
            
            if isFirstTransaction {
                _inTransaction = false
                _scheduleUpdate()
            }
            return value
        }
    }
    
    // "Mark" this observable as change in the current transaction (or the new one created by the admin).
    // This makes us track only outside-changes so we can propagate updates when all are done in the wrapped transaction.
    // If a change is done without transaction we get one here anyway, and will thus have the correct behaviour.
    func didUpdate(observable: IObservable) {
        inTransaction({
            updatedObservables[ObjectIdentifier(observable)] = observable
            #if DEBUG
            ReactionCyclicChangeDetector.shared.didSetObservable(ObjectIdentifier(observable))
            #endif
        })
    }
    
    func scheduleForUpdates(observers: [ObjectIdentifier: IObserver]) {
        // Track observers-to-update until last transaction is done
        // this won't work for the case were we change one observable
        //  multiple times in one transaction (or nested ...)
        // When exiting the last, we do this update thingy and schedule for update.
        // It should be sufficient to only track observers-to-update uniquely (we don't need to store dep. count yet then).
        inTransaction {
            _scheduleForUpdates(observers: observers)
            // TODO: I think we can use _update always?? Right now we only get here in _resolveUpdatedObservers ???
        }
    }
    
    // Two cases here which determines the startDependencyCount..
    // 1. If this is the start of the update we will call this func
    //    from '_resolveUpdatedObservers()', which source is
    //    already updated (since they come from an updated
    //    value in a transaction block). Hence no dependency count (0).
    //
    // 2. If we call this from another IObserver (atm only computed)
    //    then it hasn't updated itself but will, so all it's observers
    //    will be dependent on it and then we need a dependency count
    //    of 1.
    private func _scheduleForUpdates(observers: [ObjectIdentifier: IObserver], startDependencyCount: Int = 0) {
        assert(updatedObservables.isEmpty == false)
        observers.forEach({
            if let prevDepCount = self.pendingUpdatesDependencyCount[$0.key] {
                self.pendingUpdatesDependencyCount[$0.key] = prevDepCount + 1
            } else {
                self.pendingUpdatesDependencyCount[$0.key] = startDependencyCount
            }
            
            self.pendingUpdateList.append($0.value)
            $0.value.willUpdate()
        })
    }
    
    
    private func _scheduleUpdate() {
        if _hasScheduled == false {
            _hasScheduled = true
            DispatchQueue.main.async {
                self.transactionLock.lock()
                
                while self.updatedObservables.isEmpty == false {
                    self._resolveUpdatedObservers()
                    self._updateCurrentObservers()
                }
                
                self._hasScheduled = false
                self.transactionLock.unlock()
            }
        }
    }
    
    private func _resolveUpdatedObservers() {
        #if DEBUG
        print("Updated \(updatedObservables.count) observables")
        #endif
        for observable in updatedObservables {
            _scheduleForUpdates(observers: observable.value.observers, startDependencyCount: 0)
        }
        updatedObservables = [:]
    }
    
    private func _updateCurrentObservers() {
        print("\(pendingUpdateList.count) observers to update")
        let uniques = Set(pendingUpdateList.map({ ObjectIdentifier($0) }))
        print("\(uniques.count)) unique observers to update")
        
        for observer in pendingUpdateList {
            let id = ObjectIdentifier(observer)
            guard var depCount = pendingUpdatesDependencyCount[id] else {
                assertionFailure("Missing dep count for pending observable????")
                observer.updated()
                continue
            }
            
            if depCount <= 0 {
                print("depCount is \(depCount) => update-time!")
                observer.updated()
            } else {
                print("depCount is \(depCount) => decremented rerun later")
                depCount -= 1
                pendingUpdatesDependencyCount[id] = depCount
            }
        }
        
        assert(pendingUpdatesDependencyCount.values.contains(where: { $0 > 1 }) == false)
        pendingUpdateList = []
        pendingUpdatesDependencyCount = [:]
    }
}

#if DEBUG
final internal class ReactionCyclicChangeDetector {
    private var accessedObservables = Set<ObjectIdentifier>()
    private var settedObservables = Set<ObjectIdentifier>()
    
    static var shared = ReactionCyclicChangeDetector()
    
    private init() { }
    
    var isCyclic: Bool {
        !accessedObservables.isDisjoint(with: settedObservables)
    }
    
    func accessedObservable(_ objectId: ObjectIdentifier) {
        accessedObservables.insert(objectId)
    }
    
    func didSetObservable(_ objectId: ObjectIdentifier) {
        settedObservables.insert(objectId)
    }
    
    func clear() {
        accessedObservables.removeAll()
        settedObservables.removeAll()
    }
    
}
#endif
