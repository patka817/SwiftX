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

private struct SwiftX {
    static var observerID = 0
}

public struct ObserverView<V: View>: View {
    private var viewBuilder: () -> V
    @ObservedObject fileprivate var updater: UIUpdater
    let disposer: CancellableDisposer
    let id = SwiftX.observerID
    
    public init(@ViewBuilder viewBuilder: @escaping () -> V) {
        self.viewBuilder = viewBuilder
        let updater = UIUpdater()
        self.updater = updater
        
        var first = true
        let ctx = ObserverAdministrator.shared.addReaction({
            if first {
                _ = viewBuilder()
                first = false
            }
        }, { updater.objectWillChange.send() })
        self.disposer = CancellableDisposer(ctx.cancellable)
        
        SwiftX.observerID += 1
    }
   
    public var body: some View {
       print("(re)painting \(self.id)")
       return viewBuilder()
   }
}

public class StateProvider<State>: ObservableObject {
    public var state: State
    
    public init(_ state: State) {
        self.state = state
    }
}

private final class UIUpdater: ObservableObject, DynamicProperty { }
