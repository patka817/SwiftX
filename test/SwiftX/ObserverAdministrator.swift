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
    private var pendingUpdates = [ObjectIdentifier: Int]()
    private var pendingUpdateList = [IObserver]()
    private var _hasScheduled = false
    
    internal var currentObserverContext: (AnyObject & IObserver)? {
        get {
            transactionLock.inLock {
                return _currentObserverContext
            }
        }
    }
    internal var _currentObserverContext: (AnyObject & IObserver)?
    
    private init() { }
    
    func addReaction<V>(_ trackFunc: @escaping () -> V, _ onChange: @escaping (V) -> Void) -> ObserverContext {
        transactionLock.lock()
        #if DEBUG
        ReactionCyclicChangeDetector.shared.clear()
        #endif
        let prevCtx = _currentObserverContext
        
        let ctx = ObserverContext(closure: {
            let dataInput = trackFunc()
            onChange(dataInput)
        })
        
        _currentObserverContext = ctx
        _ = trackFunc()
        _currentObserverContext = prevCtx
        
        #if DEBUG
        assert(ReactionCyclicChangeDetector.shared.isCyclic == false, "Setting and getting the same property in a reaction is not allowed and will create an infinite loop")
        ReactionCyclicChangeDetector.shared.clear()
        #endif
        
        transactionLock.unlock()
        
        assert(ctx.isObserving, "ERROR Adding reaction but not observing changes!")
        return ctx
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
    
    func update(observers: [ObjectIdentifier: IObserver]) {
        inTransaction {
//            assert(self.runningUpdates == false)
            print("updated observable")
            observers.forEach({
                let prev = self.pendingUpdates[$0.key] ?? 0
                self.pendingUpdates[$0.key] = prev+1
                self.pendingUpdateList.append($0.value)
            })
        }
    }
    var runningUpdates = false // DEBUG ONLY
    private func _scheduleUpdate() {
        transactionLock.lock()
        if _hasScheduled == false {
            _hasScheduled = true
            DispatchQueue.main.async {
                self.transactionLock.lock()
                self.runningUpdates = true
                
                var whileLaps = 0
                var totalUpdates = 0
                #if DEBUG
                var updatedObservers = [ObjectIdentifier]()
                #endif
                
                var updateList = self.pendingUpdateList
                var dependencyCount = self.pendingUpdates
                self.pendingUpdateList.removeAll()
                self.pendingUpdates.removeAll()
                while updateList.isEmpty == false {
                    var updated = 0
                    whileLaps += 1
                    print("Listcount: \(updateList.count)")
                    for observer in updateList {
                        let id = ObjectIdentifier(observer)
                        guard let dependencyLeftCount = dependencyCount[id] else {
                            assertionFailure("Missing dep count for observable?!")
                            return
                        }
                        print("\(id) dependency count is \(dependencyLeftCount)")
                        
                        dependencyCount[id] = dependencyLeftCount - 1
                        if dependencyLeftCount > 1 {
                            print("dependencyLeftCount not zero")
                        } else {
                            totalUpdates += 1
                            updated += 1
                            // THIS CAN TRIGGER ADDITION OF OBSERVABLE UPDATES:
                            #if DEBUG
                            updatedObservers.append(id)
                            #endif
                            observer.updated()
                        }
                    }
                    
                    
                    #if DEBUG
                    print("Updated \(updated)/\(dependencyCount.count)")
                    assert(dependencyCount.contains(where: { $0.value > 0 }) == false, "Failed to update all observers")
                    #endif
                    
                    updateList = self.pendingUpdateList
                    dependencyCount = self.pendingUpdates
                    self.pendingUpdateList.removeAll()
                    self.pendingUpdates.removeAll()
                }
                
                print("\(whileLaps) nr of while-loops performed")
                print("\(totalUpdates) observers updated")
                #if DEBUG
                let unique = Set(updatedObservers)
                print("\(unique.count) unique observers updated")
                #endif
                                
                self._hasScheduled = false
                self.runningUpdates = false
                self.transactionLock.unlock()
            }
        }
        transactionLock.unlock()
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
