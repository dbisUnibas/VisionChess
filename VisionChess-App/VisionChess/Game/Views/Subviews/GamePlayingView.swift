//
//  GamePlayingView.swift
//  VisionChess
//
//  Created by Tim Bachmann on 12.03.2025.
//

import SwiftUI
import RealityKit

struct GamePlayingView: View {
    @Environment(AppModel.self) var appModel
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    
    @State var showEndGameConfirmation: Bool = false
    
    var body: some View {
        HStack {
            List {
                if teamHasPlayers(.white) {
                    TeamStatusView(team: .white)
                }
                if teamHasPlayers(.black) {
                    TeamStatusView(team: .black)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .visionChessToolbar()
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !appModel.isImmersiveSpaceOpen {
                    Button("Open Immersive Space", systemImage: "mountain.2.fill") {
                        Task {
                            await openImmersiveSpace(id: GameSpace.spaceID)
                        }
                    }
                }
                Button("End game", systemImage: "xmark") {
                    showEndGameConfirmation = true
                }
            }
        }
        .confirmationDialog("End the game for everyone?", isPresented: $showEndGameConfirmation, titleVisibility: .visible) {
            Button("End game", role: .destructive) {
                appModel.activeController?.endGame()
            }
        }
    }
    
    func teamHasPlayers(_ team: PlayerModel.Side) -> Bool {
        if let sessionController = appModel.sessionController {
            return sessionController.players.values.contains { player in
                player.side == team
            }
        } else {
            if appModel.gameController != nil {
                return true
            } else {
                return false
            }
        }
    }
}

/// A view that lists a team's players and their scores.
struct TeamStatusView: View {
    @Environment(AppModel.self) var appModel
    
    let team: PlayerModel.Side
    
    var score: Int {
        return players.map(\.score).reduce(0, +)
    }
    
    var players: [PlayerModel] {
        guard let sessionController = appModel.sessionController else {
            guard let gameController = appModel.gameController else {
                return []
            }
            
            if gameController.localPlayer.side == team {
                return [gameController.localPlayer]
            } else {
                return [PlayerModel(id: UUID(), name: "Stockfish", side: gameController.localPlayer.side == .white ? .black : .white)]
            }
        }
        
        return sessionController.players.values.filter { player in
            player.side == team
        }
        .sorted(using: KeyPathComparator(\.id))
    }
    
    var body: some View {
        Section(team.name) {
            ForEach(players) { player in
                if player.isPlaying {
                    LabeledContent(player.name, value: String(player.score))
                        .foregroundStyle(.green)
                        .bold()
                } else {
                    LabeledContent(player.name, value: String(player.score))
                }
            }
        
            HStack(spacing: 5) {
                Text("Moves:")
                ForEach(appModel.activeController?.game.moveHistory.enumerated().filter({team == .white ? $0.offset % 2 == 1 : $0.offset % 2 == 0}).map({$0.element}) ?? [], id: \.self) { move in
                    Text(move)
                }
            }
            
            HStack {
                Text("Captured Pieces:")
                ForEach(Array(appModel.activeController?.getDefeatedPieces(side: team.name.lowercased()).enumerated() ?? [].enumerated()), id: \.offset) { index, model in
                    Model3D(named: model)
                }
            }
        }
    }
}
