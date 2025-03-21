//
//  GameSpace.swift
//  VisionChess
//
//  Created by Tim Bachmann on 05.03.2025.
//

import SwiftUI
import SwiftData

struct GameSpace: Scene {
    @Environment(AppModel.self) var appModel
    @Environment(\.modelContext) var modelContext
    
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    
    let dataSource: ModelDataSource
    let modelContainer: ModelContainer
    
    init() {
        do {
            modelContainer = try ModelContainer(for: PersistedModel.self)
            dataSource = .init(context: modelContainer.mainContext)
        } catch {
            fatalError("Could not initialize ModelContainer")
        }
    }
    
    static let spaceID = "GameSpace"
    
    var body: some Scene {
        ImmersiveSpace(id: Self.spaceID) {
            GameView(dataSource: dataSource)
                .environment(appModel)
                .onAppear {
                    appModel.isImmersiveSpaceOpen = true
                }
                .onDisappear {
                    appModel.isImmersiveSpaceOpen = false
                }
        }
        .onChange(of: appModel.sessionController?.game.stage, updateImmersiveSpaceState)
        .onChange(of: appModel.gameController?.game.stage, updateImmersiveSpaceState)
    }
    
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
                appModel.initViewModel(dataSource: dataSource)
                print("Opening immersive space")
                await openImmersiveSpace(id: Self.spaceID)
            } else if !(isInGame || isInSetup) && appModel.isImmersiveSpaceOpen {
                print("Closing immersive space")
                await dismissImmersiveSpace()
            }
        }
    }
}

