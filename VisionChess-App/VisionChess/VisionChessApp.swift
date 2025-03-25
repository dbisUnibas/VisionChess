//
//  VisionChessApp.swift
//  VisionChess
//
//  Created by Tim Bachmann on 13.01.2025.
//

import SwiftUI

@main
struct VisionChessApp: App {
    @State private var appModel = AppModel()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        Group {
            VisionChessWindow()
            GameSpace()
        }
        .environment(appModel)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
                case .active:
                    print("🌞 App is active")
                    appModel.playBackgroundMusic() // Or resume if paused
                case .inactive:
                    print("💤 App is inactive")
                case .background:
                    print("🌙 App is in background")
                @unknown default:
                    break
                }
        }
    }
}
