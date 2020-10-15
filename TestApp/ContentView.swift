//
//  ContentView.swift
//  TestApp
//
//  Created by Patrik Karlsson on 2020-10-07.
//  Copyright © 2020 Patrik Karlsson. All rights reserved.
//

import SwiftUI
import SwiftX

class LifeCyclePrinter {
    init() {
        print("Init \(ObjectIdentifier(self))")
    }
    
    deinit {
        print("Deinit \(ObjectIdentifier(self))")
    }
}

struct EmptyDebugView: View {
    let deinitPrinter = LifeCyclePrinter()
    
    var body: some View {
        EmptyView()
    }
}

struct CounterView: View {
    @EnvironmentObject var stateProvider: StateProvider<AppState>
    @EnvironmentObject var publishedStateProvider: StateProvider<PublishedState>
    @EnvironmentObject var envState: EnvAppState
    var state: AppState { stateProvider.state }
    @Binding var count: Int
    @State var text = ""
    
    var body: some View {
//        ObserverView {
        VStack {
//            ObserverView {
                Text(self.state.greeting)
//            }
            
//            Text("Count: \(self.count)")
//            Text("Count: \(self.envState.count)")
//            Text("Count: \(self.state.count)")
//            CounterLabel()
            ObserverView {
                Text("Count: \(self.state.count)")
            }
            HStack {
                Button(action: {
//                    self.envState.count += 1
//                    self.count += 1
                    self.state.count += 1
//                    self.publishedStateProvider.state.count += 1
                }, label: { Text("+") })
                Button(action: {
//                    self.envState.count -= 1
//                    self.count -= 1
                    self.state.count -= 1
//                    self.publishedStateProvider.state.count -= 1
                }, label: { Text("-") })
            }
        }
//        }
    }
}

struct CounterLabel: View {
    @EnvironmentObject var publishedStateProvider: StateProvider<PublishedState>
    @State var publishedCount = 0
    
    var body: some View {
        Text("Count: \(self.publishedCount)")
            .onReceive(publishedStateProvider.state.$count, perform: { self.publishedCount = $0
            })
    }
}

struct MassiveCounterView: View {
    @Binding var count: Int
    var body: some View {
        VStack {
            Group {
            CounterView(count: self.$count)
            CounterView(count: self.$count)
            CounterView(count: self.$count)
            CounterView(count: self.$count)
            CounterView(count: self.$count)
            CounterView(count: self.$count)
            CounterView(count: self.$count)
            CounterView(count: self.$count)
            }
            Group {
            CounterView(count: self.$count)
            CounterView(count: self.$count)
            CounterView(count: self.$count)
            CounterView(count: self.$count)
            CounterView(count: self.$count)
            CounterView(count: self.$count)
            CounterView(count: self.$count)
            CounterView(count: self.$count)
            }
            Group {
            CounterView(count: self.$count)
            CounterView(count: self.$count)
            CounterView(count: self.$count)
            CounterView(count: self.$count)
            CounterView(count: self.$count)
            CounterView(count: self.$count)
            CounterView(count: self.$count)
            CounterView(count: self.$count)
            }
            Group {
            CounterView(count: self.$count)
            CounterView(count: self.$count)
            CounterView(count: self.$count)
            CounterView(count: self.$count)
            CounterView(count: self.$count)
            CounterView(count: self.$count)
            CounterView(count: self.$count)
            CounterView(count: self.$count)
            }
        }
    }
}

struct ContentView: View {
    @State var showSheet = false
    @State var count = 0
    
    @State var greeting = ""
    @EnvironmentObject var stateProvider: StateProvider<AppState>
    var showOtherButton: some View {
        Button("Show more", action: {
            self.showSheet = true
        })
    }
    
    var body: some View {
            VStack {
                ObserverView {
                Text(self.stateProvider.state.mainContentGreeting).font(.largeTitle)
                }
                showOtherButton.padding()
                CounterView(count: self.$count)
                CounterView(count: self.$count)
                CounterView(count: self.$count)
                CounterView(count: self.$count)
                CounterView(count: self.$count)
//                ObserverView {
                TextField("Change titlne", text: self.stateProvider.state.$mainContentGreeting).border(Color.blue)
//                }
            }.sheet(isPresented: self.$showSheet, content: {
                MassiveCounterView(count: self.$count)
            })
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
