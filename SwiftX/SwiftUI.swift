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

// TODO: Test having @State in the supplied viewbuilder and make sure we
// rerender when it triggers..
public struct ObserverView<V: View>: View {
    private var viewBuilder: () -> V
    @ObservedObject fileprivate var updater: UIUpdater<V>
    let disposer: CancellableDisposer
    let id = SwiftX.observerID
    
    public init(@ViewBuilder viewBuilder: @escaping () -> V) {
        self.viewBuilder = viewBuilder
        let updater = UIUpdater<V>()
        self.updater = updater
        
        let ctx = ObserverAdministrator.shared.addReaction({
            updater.content = viewBuilder()
        }, {
            updater.objectWillChange.send()
        })
        self.disposer = CancellableDisposer(ctx.cancellable)
        
        SwiftX.observerID += 1
    }
   
    public var body: some View {
       print("(re)painting \(self.id)")
        return updater.content
   }
}

public class StateProvider<State>: ObservableObject {
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
