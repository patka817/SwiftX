//
//  SwiftUI.swift
//  test
//
//  Created by Patrik Karlsson on 2020-10-05.
//  Copyright © 2020 Patrik Karlsson. All rights reserved.
//

import Foundation
import Combine
import SwiftUI

public struct ObserverView<V: View>: View {
    private var viewBuilder: () -> V
    @ObservedObject fileprivate var updater: UIUpdater<V>
    let disposer: CancellableDisposer
    var name: String?
    
    public init(_ name: String? = nil, @ViewBuilder viewBuilder: @escaping () -> V) {
        self.viewBuilder = viewBuilder
        self.name = name
        let updater = UIUpdater<V>()
        self.updater = updater
        
        let cancel = reaction(named: name, {
            updater.content = viewBuilder()
        }, {
            if Thread.isMainThread {
                updater.objectWillChange.send()
            } else {
                DispatchQueue.main.async {
                    updater.objectWillChange.send()
                }
            }
        })
        self.disposer = CancellableDisposer(cancel)
    }
   
    public var body: some View {
//        print("(re)painting \(self.name)")
        return updater.content
   }
}

public final class StateProvider<State>: ObservableObject {
    public var state: State
    
    public init(_ state: State) {
        self.state = state
    }
}

private final class UIUpdater<V: View>: ObservableObject, DynamicProperty {
    var content: V?
}
