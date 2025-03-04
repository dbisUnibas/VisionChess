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

    var body: some Scene {
        #if os(visionOS)
        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            GameView()
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        #else
        WindowGroup {
            ContentView()
                .environment(appModel)
        }
        #endif
     }
}
