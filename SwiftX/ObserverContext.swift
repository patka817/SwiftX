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

private var id = 0

protocol IObserver: AnyObject {
    var isObserving: Bool { get set }
    
    func didAccess(observable: IObservable)
    func willUpdate()
    func updated()
    func cancel()
}

final internal class ObserverContext: IObserver {
    private var observingObservables = [ObjectIdentifier: Weak<(IObservable)>]()
    var closure: ((ObserverContext) -> Void)?
    var cancellable: AnyCancellable!
    var isObserving = false
    private var _isTrackingRemovals = false
    private var _observersAccessed = Set<ObjectIdentifier>()
    
    #if DEBUG
    let observerID: Int = {
        let obsID = id
        id += 1
        return obsID
    }()
    #endif
    
    init(closure: @escaping (ObserverContext) -> Void) {
        self.closure = closure
        self.cancellable = AnyCancellable({ [weak self] in
            guard let self = self else { return }
            self.closure = nil
            self.observingObservables.forEach({ $0.value.value?.onObserverCancelled(self)
            })
        })
    }
    
    func startTrackingRemovals() {
        _isTrackingRemovals = true
    }
    
    func stopTrackingRemovals() {
        _isTrackingRemovals = false
        observingObservables.forEach({
            if _observersAccessed.contains($0.key) == false {
                $0.value.value?.onObserverCancelled(self)
            }
        })
        _observersAccessed.removeAll() 
    }
    
    func didAccess(observable: IObservable) {
        let id = ObjectIdentifier(observable)
        if observingObservables[id] == nil {
            observingObservables[id] = Weak(observable)
        }
        
        if _isTrackingRemovals {
            _observersAccessed.insert(id)
        }
        isObserving = true
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
