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
    let id = SwiftX.observerID
    
    public init(@ViewBuilder viewBuilder: @escaping () -> V) {
        self.viewBuilder = viewBuilder
        let updater = UIUpdater<V>()
        self.updater = updater
        
        let cancel = autorun {
            updater.content = viewBuilder()
            updater.objectWillChange.send()
        }
        self.disposer = CancellableDisposer(cancel)
        SwiftX.observerID += 1
    }
   
    public var body: some View {
//       print("(re)painting \(self.id)")
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

private struct SwiftX {
    static var observerID = 0
}
