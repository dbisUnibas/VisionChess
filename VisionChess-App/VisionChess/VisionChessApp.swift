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
        Group {
            VisionChessWindow()
            GameSpace()
        }
        .environment(appModel)
    }
}
