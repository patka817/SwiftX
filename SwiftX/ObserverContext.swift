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

final internal class ObserverContext: IObserver {
    internal var observingObservables = [ObjectIdentifier: Weak<(IObservable)>]()
    internal var observingObservablesLock = os_unfair_lock_s()
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
            self.unobserveFromAllObservables()
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
