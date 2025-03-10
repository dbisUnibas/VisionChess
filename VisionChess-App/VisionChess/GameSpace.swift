//
//  GameSpace.swift
//  VisionChess
//
//  Created by Tim Bachmann on 05.03.2025.
//
import SwiftUI

struct GameSpace: Scene {
    @Environment(AppModel.self) var appModel
    
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    
    static let spaceID = "GameSpace"
    
    var body: some Scene {
        ImmersiveSpace(id: Self.spaceID) {
            GameView()
                .environment(appModel)
                .onAppear {
                    appModel.isImmersiveSpaceOpen = true
                }
                .onDisappear {
                    appModel.isImmersiveSpaceOpen = false
                }
        }
        .onChange(of: appModel.sessionController?.game.stage, updateImmersiveSpaceState)
    }
    
    /// Opens or dismisses the app's immersive space based on the game's current and previous states.
    ///
    /// - Parameters:
    ///     - oldActivityStage: The app's previous activity stage.
    ///     - newActivityStage: The app's current stage.
    func updateImmersiveSpaceState(
        oldActivityStage: GameModel.ActivityStage?,
        newActivityStage: GameModel.ActivityStage?
    ) {
        let wasInGame = oldActivityStage?.isInGame ?? false
        let isInGame = newActivityStage?.isInGame ?? false
        let wasInSetup = oldActivityStage == .inSetup
        let isInSetup = newActivityStage == .inSetup
        
        
        
        guard wasInGame != isInGame || wasInSetup != isInSetup else {
            return
        }
        
        Task {
            if isInSetup && !appModel.isImmersiveSpaceOpen {
                print("Opening immersive space")
                await openImmersiveSpace(id: Self.spaceID)
            } else if !(isInGame || isInSetup) && appModel.isImmersiveSpaceOpen {
                print("Closing immersive space")
                await dismissImmersiveSpace()
            }
        }
    }
}

