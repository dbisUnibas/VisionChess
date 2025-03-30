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
//            List {
//                if teamHasPlayers(.white) {
//                    TeamStatusView(team: .white)
//                }
//                if teamHasPlayers(.black) {
//                    TeamStatusView(team: .black)
//                }
//            }
//            .scrollDisabled(true)
//            .frame(maxWidth: .infinity)
            appModel.gameController?.image?
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 500, height: 500)
            
//            VStack {
//                ForEach(appModel.gameController?.fen ?? [], id: \.self) { fen in
//                    Text(fen)
//                }
//            }
            
            var flatData: [String] {
                appModel.gameController?.fen.flatMap { $0 } ?? []
            }
                
            let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 8)
            
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(flatData.indices, id: \.self) { index in
                    Text(flatData[index])
                        .frame(minWidth: 95, minHeight: 60)
                        .border(Color.white)
                }
            }
            .padding()
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
                HStack(alignment: .top) {
                    PlayerView(player: player)
                    MovesView(team: team)
                    CapturedPiecesView(team: team)
                }
            }
        }
    }
}

struct PlayerView: View {
    @Environment(AppModel.self) var appModel
    let player: PlayerModel
    
    var localPlayer: PlayerModel? {
        guard let activeController = appModel.activeController else {
            return nil
        }
        
        return activeController.localPlayer
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 5) {
            // Player Image
            Group {
                if player.name == "Stockfish" {
                    Image("stockfishLogo")
                        .resizable()
                        .frame(width: 86, height: 86)
                } else {
                    Image(systemName: "person.fill")
                        .resizable()
                        .frame(width: 64, height: 64)
                        .padding(11)
                }
            }
            
            // Player Name & Status
            let playerDisplayName = player.name == "Stockfish" ? "\(player.name) \n\(appModel.activeController?.opponentStrength.rawValue ?? "")" : player.name
            let isActive = player.isPlaying || (player.name == "Stockfish" && localPlayer?.isPlaying == false)

            Text(playerDisplayName)
                .foregroundStyle(isActive ? .green : .primary)
                .bold(isActive)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}


struct CapturedPiecesView: View {
    @Environment(AppModel.self) var appModel
    let team: PlayerModel.Side
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Captured Pieces")
                .bold()
            HStack {
                ForEach(Array(appModel.activeController?.getDefeatedPieces(side: team.name.lowercased()).enumerated() ?? [].enumerated()), id: \.offset) { index, model in
                    Model3D(named: model)
                }
            }
        }.padding()
    }
}

struct MovesView: View {
    @Environment(AppModel.self) var appModel
    let team: PlayerModel.Side
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Moves")
                .bold()
            List {
                ForEach(appModel.activeController?.game.moveHistory.enumerated().filter({team == .white ? $0.offset % 2 == 0 : $0.offset % 2 == 1}).map({$0.element}) ?? [], id: \.self) { move in
                    Text(move)
                }
            }
        }.padding()
    }
}
