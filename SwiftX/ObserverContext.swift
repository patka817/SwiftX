//
//  ObserverContext.swift
//  test
//
//  Created by Patrik Karlsson on 2020-09-29.
//  Copyright © 2020 Patrik Karlsson. All rights reserved.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Private


internal protocol IObserver: AnyObject {
    var observingObservables: [ObjectIdentifier: Weak<IObservable>] { get set }
    var isObserving: Bool { get set }
    
    var _isTrackingRemovals: Bool { get set }
    var _observablesAccessed: Set<ObjectIdentifier> { get set }
    
    func didAccess(observable: IObservable)
    func willUpdate()
    func updated()
    func cancel()
}

extension IObserver {
    func startTrackingRemovals() {
        _isTrackingRemovals = true
    }

    func stopTrackingRemovals() {
        _isTrackingRemovals = false
        observingObservables = observingObservables.filter({
            if _observablesAccessed.contains($0.key) == false {
                $0.value.value?.onObserverCancelled(self)
                return false
            }
            return true
        })
        _observablesAccessed.removeAll()
    }

    func didAccess(observable: IObservable) {
        let id = ObjectIdentifier(observable)
        if observingObservables[id] == nil {
            observingObservables[id] = Weak(observable)
        }
        
        if _isTrackingRemovals {
            _observablesAccessed.insert(id)
        }
        isObserving = true
    }
    
}

final internal class ObserverContext: IObserver {
    internal var observingObservables = [ObjectIdentifier: Weak<(IObservable)>]()
    var closure: ((ObserverContext) -> Void)?
    var cancellable: AnyCancellable!
    var isObserving = false
    internal var _isTrackingRemovals = false
    internal var _observablesAccessed = Set<ObjectIdentifier>()
    
    init(closure: @escaping (ObserverContext) -> Void) {
        self.closure = closure
        self.cancellable = AnyCancellable({ [weak self] in
            guard let self = self else { return }
            self.closure = nil
            self.observingObservables.forEach({ $0.value.value?.onObserverCancelled(self)
            })
        })
    }
    
    func updated() {
        closure?(self)
    }
    
    func willUpdate() { }
    
    func cancel() {
        cancellable.cancel()
    }
}

final internal class CancellableDisposer {
    var cancellable: AnyCancellable?
    
    init(_ cancellable: AnyCancellable?) {
        self.cancellable = cancellable
    }
    
    deinit {
        self.cancellable?.cancel()
    }
}
