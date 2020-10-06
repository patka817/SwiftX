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

 protocol IObserver: AnyObject {
    typealias OnCancelCallback = (Self) -> Void
    var cancelled: Bool { get }
    var isObserving: Bool { get set }
    
    func updated()
    func cancel()
    func onCancel(_ closure: @escaping OnCancelCallback)
}

final internal class ObserverContext: IObserver {
    private var onCancelCallbacks = [OnCancelCallback]()
    var closure: (() -> Void)?
    var cancellable: AnyCancellable!
    var cancelled: Bool { self.closure == nil }
    var isObserving = false
    
    init(closure: @escaping () -> Void) {
        self.closure = closure
        self.cancellable = AnyCancellable({ [weak self] in
            guard let self = self else { return }
            self.closure = nil
            self.onCancelCallbacks.forEach({ $0(self) })
        })
    }
    
    func updated() {
        closure?()
    }
    
    func cancel() {
        cancellable.cancel()
    }
    
    func onCancel(_ closure: @escaping OnCancelCallback) {
        onCancelCallbacks.append(closure)
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
