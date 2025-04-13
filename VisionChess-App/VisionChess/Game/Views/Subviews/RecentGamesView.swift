//
//  ModeSelectionView.swift
//  VisionChess
//
//  Created by Tim Bachmann on 12.03.2025.
//

import SwiftUI
import OpenAPIClient


struct RecentGamesView: View {
    @Environment(AppModel.self) var appModel
    @State var games: [GameResponse] = []
    let deviceId = UIDevice.current.identifierForVendor?.uuidString
    
    var body: some View {
        VStack(alignment: .leading) {
            Section {
                List {
                    ForEach(games, id: \.id) { game in
                        GameListItem(game: game)
                    }
                }
                    
            } header: {
                Text("Recent Games")
            } footer: {
                Text("Select a game you'd like to review.")
            }
            
        }
        .padding(32)
        .frame(width: 900)
        .visionChessToolbar()
        .toolbar {
            if appModel.reviewController != nil {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button("Back", systemImage: "chevron.left") {
                        appModel.reviewController = nil
                    }
                }
            }
        }
        .onAppear {
//            #if targetEnvironment()
//            self.games = [GameResponse(id: "75843975935435", gameState: "", moves: [], white: deviceId ?? "", black: "", checkers: [], opponentStrength: 1, opponent: .virtual, winner: ""), GameResponse(id: "432532645645", gameState: "", moves: [], white: deviceId ?? "", black: "", checkers: [], opponentStrength: 1, opponent: .virtual, winner: ""), GameResponse(id: "42343", gameState: "", moves: [], white: deviceId ?? "", black: "", checkers: [], opponentStrength: 1, opponent: .virtual, winner: ""), GameResponse(id: "4645664", gameState: "", moves: [], white: deviceId ?? "", black: "", checkers: [], opponentStrength: 1, opponent: .virtual, winner: ""), GameResponse(id: "4534534", gameState: "", moves: [], white: deviceId ?? "", black: "", checkers: [], opponentStrength: 1, opponent: .virtual, winner: ""), GameResponse(id: "6765757", gameState: "", moves: [], white: deviceId ?? "", black: "", checkers: [], opponentStrength: 1, opponent: .virtual, winner: ""), GameResponse(id: "7867868", gameState: "", moves: [], white: deviceId ?? "", black: "", checkers: [], opponentStrength: 1, opponent: .virtual, winner: ""), GameResponse(id: "6874883", gameState: "", moves: [], white: deviceId ?? "", black: "", checkers: [], opponentStrength: 1, opponent: .virtual, winner: "")]
//            #else
            GamesAPI.gamesGet { response, error  in
                guard let games = response else {
                    print("Error fetching games: \(error ?? "No error description available")")
                    return
                }
                self.games = games //.filter({$0.white == deviceId || $0.black == deviceId})
            }
//            #endif
        }
    }
}

struct GameListItem: View {
    @Environment(AppModel.self) var appModel
    var game: GameResponse

    var body: some View {
        HStack {
            Text(game.id)
                .font(.body)
            
            
            Spacer()
            
            Text("\(String(game.moves.count)) Moves")
                .font(.body)
                .padding([.leading, .trailing], 24.0)
            
            Button("Review", systemImage: "chart.line.text.clipboard") {
                appModel.activeController?.setGameID(game.id)
                appModel.activeController?.setMoveHistory(game.moves)
                appModel.activeController?.enterTeamSelection(gameMode: .review)
            }
            .padding([.leading, .trailing], 14.0)
            .padding([.top, .bottom], 6.0)
            .background(.gray)
            .foregroundStyle(.white)
            .clipShape(.capsule)
            
        }
    }
}

struct RecentGamesView_Previews: PreviewProvider {
    static let appModel = AppModel()

    static var previews: some View {
        RecentGamesView()
            .environment(appModel)
            .glassBackgroundEffect()
            .frame(width: 900, height: 600)
    }
}
