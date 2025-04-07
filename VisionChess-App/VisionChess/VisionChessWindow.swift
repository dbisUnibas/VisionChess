//
//  VisionChessWindow.swift
//  VisionChess
//
//  Created by Tim Bachmann on 05.03.2025.
//

import SwiftUI

struct VisionChessWindow: Scene {
    @Environment(AppModel.self) var appModel
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                MainView()
            }
            .frame(width: 900, height: 620)
            .nameAlert()
        }
        .windowResizability(.contentSize)
        
        WindowGroup("Move Window", id: "moveWindow") {
            MoveView()
        }
        .windowResizability(.contentSize)
    }
}


