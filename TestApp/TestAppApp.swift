//
//  TestAppApp.swift
//  TestApp
//
//  Created by Patrik Karlsson on 2020-10-07.
//  Copyright © 2020 Patrik Karlsson. All rights reserved.
//

import SwiftUI
import SwiftX

@main
struct TestAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(StateProvider(AppState()))
                .environmentObject(EnvAppState())
                .environmentObject(StateProvider(PublishedState()))
        }
    }
}

// ----------- TEST -----------

class AppState {
    @Observable var greeting = "Hej"
    @Observable var count = 0
    @Observable var mainContentGreeting = "Hello counter world"
    @Observable var nilable: String? = nil
    @Observable var testTrigger = false
}

class EnvAppState: ObservableObject {
    @Published var count = 0
}

class PublishedState {
    @Published var count = 0
}

// -----------
