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
    
    func addReaction<V>(named name: String?, _ trackFunc: @escaping () -> V, _ onChange: @escaping (V) -> Void) -> ObserverContext {
        let ctx = ObserverContext(name: name, closure: { ourSelf in
            // if we run this in a context, we get re-added as observer for "lost" props.
            // We remove ourself from those we have accessed but aren't accessing in this run (so we dont get updated if e.g. moved observables is updated).
            // (we are always run inside an update-loop, hence no need for locking)
            #if DEBUG
            if self.transactionLock.tryLock() == false {
                assertionFailure("RUNNING UPDATE IN NON-TRANSACTION ?!?!")
            } else {
                self.transactionLock.unlock()
            }
            #endif
            let prevCtx = self._currentObserverContext
            self._currentObserverContext = ourSelf
            
            #if DEBUG
            ReactionCyclicChangeDetector.beginTracking()
            #endif
            
            ourSelf.startTrackingRemovals()
            let dataInput = trackFunc()
            ourSelf.stopTrackingRemovals()
            onChange(dataInput)
            
            #if DEBUG
            ReactionCyclicChangeDetector.doneTracking()
            #endif
            self._currentObserverContext = prevCtx
        })
        addReaction(observer: ctx, trackFunc)
        return ctx
    }
    
    func addReaction<V, O: IObserver>(observer: O, _ trackFunc: @escaping () -> V) {
        transactionLock.lock()
        let prevCtx = _currentObserverContext
        
        #if DEBUG
        ReactionCyclicChangeDetector.beginTracking()
        #endif
        
        _currentObserverContext = observer
        _ = trackFunc()
        _currentObserverContext = prevCtx
        
        #if DEBUG
        ReactionCyclicChangeDetector.doneTracking()
        #endif 
        transactionLock.unlock()
//        assert(observer.isObserving, "ERROR Adding reaction but not observing changes!")
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
    
    var start = Date()
    #if DEBUG
    var totalUpdateTime: Double = 0
    var updates: Double = 0
    #endif
    func inTransaction<V>(_ transaction: () -> V) -> V {
        transactionLock.inLock {
            let isFirstTransaction = _inTransaction == false
//            #if DEBUG
            if isFirstTransaction {
                start = Date()
            }
//            #endif
            _inTransaction = true
            
            let value = transaction()
            
            if isFirstTransaction {
                _scheduleUpdate()
                // Set the intransaction AFTER we run updates..
                // otherwise we might trigger something
                // in scheduleUpdate which re-enters transaction
                // which then thinks it is the first transaction..
                _inTransaction = false
                
                let time = Date().timeIntervalSince(start)
                #if DEBUG
                totalUpdateTime += time
                updates += 1
                print("Update took \(time)s. Avg is: \(totalUpdateTime/updates)s")
                #endif
                if time > 0.01 {
                    NSLog("!!!!!!!!!! \(time) !!!!!!!!!")
                }
            }
            return value
        }
    }
    
    // "Mark" this observable as changed in the current transaction (or the new one created).
    // This makes us track only outside-changes so we can propagate updates when all are done in the wrapped transaction.
    // If a change is done without transaction we get one here anyway, and will thus have the correct behaviour.
    func didUpdate(observable: IObservable) {
        inTransaction({
            updatedObservables[ObjectIdentifier(observable)] = observable
            #if DEBUG
            ReactionCyclicChangeDetector.current.didSetObservable(ObjectIdentifier(observable))
            #endif
        })
    }
    
    func scheduleForUpdates(observers: [ObjectIdentifier: IObserver]) {
        // When exiting the last, we do this update thingy and schedule for update.
        // It should be sufficient to only track observers-to-update uniquely (we don't need to store dep. count yet then).
        #if DEBUG
        if transactionLock.tryLock() == false {
            assertionFailure()
        }
        transactionLock.unlock()
        #endif
        _scheduleForUpdates(observers: observers)
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
    // OR?!?!?! Seems to work with 0 as start, always........... hmmm
    private func _scheduleForUpdates(observers: [ObjectIdentifier: IObserver]) {
        assert(updatedObservables.isEmpty == false)
        observers.forEach({
            if let prevDepCount = self.pendingUpdatesDependencyCount[$0.key] {
                self.pendingUpdatesDependencyCount[$0.key] = prevDepCount + 1
            } else {
                self.pendingUpdatesDependencyCount[$0.key] = 0
            }
            
            self.pendingUpdateList.append($0.value)
            $0.value.willUpdate()
        })
    }
    
    
    private func _scheduleUpdate() {
        // Not sure if we should run async or not..
        // Pro's running sync is that changes happen directly
        // which is easier to debug and reason about.
        // But it might affect perfomance? Might cause
        // issues in UI? And unable to guarentee what thread we run all closures on..
        // Need to investigate it..
        
        // If we run async we can "accidentally" batch updates
        // (two updates to observables after each other).
        // And we can guarentee mainthread on callbacks..
        // Might cost more (or less?) in terms of perfomance?
        // Can be harder to debug/reason..
        
//        if _hasScheduled == false {
//            _hasScheduled = true
//            DispatchQueue.main.async {
//                self.transactionLock.lock()
                
                while self.updatedObservables.isEmpty == false {
                    self._resolveUpdatedObservers()
                    self._updateCurrentObservers()
                }
                
//                self._hasScheduled = false
//                self.transactionLock.unlock()
//            }
//        }
    }
    
    private func _resolveUpdatedObservers() {
        #if DEBUG
        print("Updated \(updatedObservables.count) observables")
        #endif
        for observable in updatedObservables {
            _scheduleForUpdates(observers: observable.value.observers)
        }
        updatedObservables = [:]
    }
    
    private func _updateCurrentObservers() {
        #if DEBUG
        print("\(pendingUpdateList.count) observers to update")
        let uniques = Set(pendingUpdateList.map({ ObjectIdentifier($0) }))
        print("\(uniques.count)) unique observers to update: \(uniques.map({ "\($0)" }).joined(separator: ", "))")
        #endif
        
        for observer in pendingUpdateList {
            let id = ObjectIdentifier(observer)
            guard var depCount = pendingUpdatesDependencyCount[id] else {
                assertionFailure("Missing dep count for pending observable????")
                observer.updated()
                continue
            }
            
            if depCount == 0 {
                #if DEBUG
                print("depCount is \(depCount) => update-time!")
                #endif
                observer.updated() // need to run on main..!?
                #if DEBUG
                depCount -= 1
                pendingUpdatesDependencyCount[id] = depCount
                #endif
            } else {
                #if DEBUG
                print("depCount is \(depCount) => decremented rerun later")
                #endif
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
    
    static var current = ReactionCyclicChangeDetector()
    static private var lastCurrent: ReactionCyclicChangeDetector?
    
    static func beginTracking() {
        lastCurrent = current
        current = ReactionCyclicChangeDetector()
    }
    
    static func doneTracking() {
        assert(current.isCyclic == false)
        current = lastCurrent ?? ReactionCyclicChangeDetector()
    }
    
    private init() { }
    
    var isCyclic: Bool {
        !accessedObservables.isDisjoint(with: settedObservables)
    }
    
    var objectIdBothAccessedAndSet: ObjectIdentifier? {
        accessedObservables.first(where: { settedObservables.contains($0) })
    }
    
    // TODO fix when autorun trigger another autorun by setting an observable  value that the other autorun listens to...
    func accessedObservable(_ objectId: ObjectIdentifier) {
        guard ObserverAdministrator.shared._currentObserverContext != nil else { return }
        accessedObservables.insert(objectId)
        assert(isCyclic == false, "cyclic dependency detected for ObjectId \(objectId)")
    }
    
    func didSetObservable(_ objectId: ObjectIdentifier) {
        guard ObserverAdministrator.shared._currentObserverContext != nil else { return }
        settedObservables.insert(objectId)
        assert(isCyclic == false, "cyclic dependency detected for ObjectId \(objectId)")
    }
}
#endif
