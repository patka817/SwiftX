//
//  SceneDelegate.swift
//  test
//
//  Created by Patrik Karlsson on 2020-09-29.
//  Copyright © 2020 Patrik Karlsson. All rights reserved.
//

import UIKit
import SwiftUI
import Combine

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

// -----------

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    @Observable var cryBaby = false
    @Observable var multiplier = 2
    var computed: Computed<String>!
    
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).

        // Create the SwiftUI view that provides the window contents.
        let state = AppState()
        
        computed = Computed({
            return "COMPUTED got count \(state.count)"
        })
        // runtimes:
        // 0.07173597812652588
        // 0.07014095783233643
        // 0.06776607036590576
        var start: Date!
        autorun {
            print("Autorun on computed (last in updatelist) got computed \(self.computed.value)")
            print("Autorun got count \(state.count)")
            if state.count == 4 {
                print("Update time \(Date().timeIntervalSince(start))")
            }
        }
        
        start = Date()
        inTransaction {
            state.count = 1
            inTransaction {
                state.count = 2
                inTransaction {
                    state.count = 3
                }
            }
            inTransaction {
                state.count = 4
            }
        }
//
//        let superCOmputed = Computed({
//            print("super!:::: \(self.computed.value)")
//        })
//
//        autorun {
//            print(superCOmputed.value)
//        }
//
//        autorun {
//            print("First autorun for computed: \(self.computed.value)")
//        }
//
//        DispatchQueue.global().asyncAfter(deadline: .now() + 8, execute: {
//            autorun {
//                print("Second autorun for computed: \(self.computed.value)")
//            }
//
//            DispatchQueue.global().asyncAfter(deadline: .now() + 2, execute: {
//                state.count = 0
//            })
//        })
        
        let contentView = ContentView().environmentObject(StateProvider(state)).environmentObject(EnvAppState())
        
//        _ = autorun({
//            print("Updated count to \(state.count)")
//        })
        
//        inTransaction {
//            state.count = -666
//            autorun {
//                print("In transaction: \(state.count) --- \(state.greeting)")
//            }
//        }
        
//        let reactionCancel = reaction({
//            return (state.mainContentGreeting, state.count, self.cryBaby)
//        }, {
//            print("Reacted to (\($0.0), \($0.1), \($0.2))")
//        })
        
//        for i in 0...500 {
//            DispatchQueue.global().asyncAfter(deadline: .now() + 1, execute: {
//                inTransaction({
//                    state.count = i
//                    inTransaction({
//                        state.count = i
//                        state.mainContentGreeting = "Damn boyo! \(i)"
//                    })
//
//                    state.mainContentGreeting = "Boyo Damn! \(i)"
//                })
//            })
//        }
        
//        DispatchQueue.global().asyncAfter(deadline: .now() + 5, execute: {
//            self.cryBaby.toggle()
//            DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
//                reactionCancel.cancel()
//            })
//        })

        // Use a UIHostingController as window root view controller.
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: contentView)
            self.window = window
            window.makeKeyAndVisible()
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}

