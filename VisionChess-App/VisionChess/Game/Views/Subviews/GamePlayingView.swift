/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A view that displays each team's score next to the round's timer during a game.
*/

import SwiftUI
import RealityKit

struct GamePlayingView: View {
    @Environment(AppModel.self) var appModel
    
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
        .guessTogetherToolbar()
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("End game", systemImage: "xmark") {
                    showEndGameConfirmation = true
                }
            }
        }
        .confirmationDialog("End the game for everyone?", isPresented: $showEndGameConfirmation, titleVisibility: .visible) {
            Button("End game", role: .destructive) {
                appModel.sessionController?.endGame()
            }
        }
    }
    
    func teamHasPlayers(_ team: PlayerModel.Side) -> Bool {
        if let sessionController = appModel.sessionController {
            return sessionController.players.values.contains { player in
                player.side == team
            }
        } else {
            return false
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
            return []
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
                    LabeledContent(player.name, value: player.score.description)
                        .foregroundStyle(.green)
                        .bold()
                } else {
                    LabeledContent(player.name, value: player.score.description)
                }
            }
            
            VStack(spacing: 12) {
                Text("Captured Pieces:")
                
                HStack {
                    ForEach(Array(appModel.viewModel?.gameManager?.getDefeatedPieces(side: team.name).enumerated() ?? [].enumerated()), id: \.offset) { index, model in
                        Model3D(named: model)
                    }
                }
            }
        }
    }
}
