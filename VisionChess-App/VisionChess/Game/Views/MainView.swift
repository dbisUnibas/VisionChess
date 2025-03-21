//
//  MainView.swift
//  VisionChess
//
//  Created by Tim Bachmann on 12.03.2025.
//

import GroupActivities
import SwiftUI

struct MainView: View {
    @Environment(AppModel.self) var appModel
    
    var body: some View {
        Group {
            // Select the appropriate view for each stage in the game.
            switch appModel.activeController?.game.stage {
                case .none:
                    WelcomeView()
                case .modeSelection:
                    ModeSelectionView()
                case .sideSelection:
                    TeamSelectionView()
                case .inSetup:
                    BoardSetupView()
                case .inGame:
                    GamePlayingView()
                case .gameOver:
                    GameOverView()
            }
        }
        .task(observeGroupSessions)
    }
    
    /// Monitor for new Guess Together group activity sessions.
    @Sendable
    func observeGroupSessions() async {
        for await session in ChessGroupActivity.sessions() {
            let sessionController = await SessionController(session, appModel: appModel)
            guard let sessionController else {
                continue
            }
            appModel.sessionController = sessionController

            // Create a task to observe the group session state and clear the
            // session controller when the group session invalidates.
            Task {
                for await state in session.$state.values {
                    guard appModel.sessionController?.session.id == session.id else {
                        return
                    }

                    if case .invalidated = state {
                        appModel.sessionController = nil
                        return
                    }
                }
            }
        }
    }
}
