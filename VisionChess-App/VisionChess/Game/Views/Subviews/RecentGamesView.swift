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
    @State var contentLoaded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading) {
            if contentLoaded == true {
                Section {
                    List {
                        ForEach(games, id: \.id) { game in
                            GameListItem(game: game)
                        }
                    }
                    .refreshable {
                        loadGames()
                    }
                } header: {
                    Text("Recent Games")
                } footer: {
                    Text("Select a game you'd like to review.")
                }
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
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
            loadGames()
        }
    }
}

extension RecentGamesView {
    func loadGames() {
        GamesAPI.gamesGet { response, error  in
            guard let games = response else {
                print("Error fetching games: \(error ?? "No error description available")")
                return
            }
            
            let idFiltered = games.filter { item in
                let whitePrefix = String(item.white.split(separator: "//").first ?? "")
                let blackPrefix = String(item.black.split(separator: "//").first ?? "")
                return !item.moves.isEmpty && (whitePrefix == deviceId || blackPrefix == deviceId)
            }
            self.games = idFiltered
            contentLoaded = true
        }
    }
}

struct GameListItem: View {
    @Environment(AppModel.self) var appModel
    var game: GameResponse

    var body: some View {
        let winnerColor: Color? = game.winner == game.white ? Color.white : game.winner == game.black ? Color.black : nil
        
        HStack {
            
            HStack {
                Text("♚ ")
                    .font(.title)
                    .foregroundStyle(.white)
                    .italic()
                    .padding(.bottom, 8)
                Text("\(game.white.split(separator: "//").last ?? "")")
                    .font(.body)
                    .foregroundStyle(.white)
            }
            
            Divider()
                .padding([.leading, .trailing], 24.0)
                .padding([.top, .bottom], 8.0)
            
            HStack {
                Text("♚ ")
                    .font(.title)
                    .foregroundStyle(.black)
                    .italic()
                    .padding(.bottom, 8)
                
                Text("\(game.black.split(separator: "//").last ?? "")")
                    .font(.body)
                    .foregroundStyle(.white)
            }
            
            Spacer()
            
            Text("\(String(game.moves.count)) Moves")
                .font(.body)
                .padding([.leading], 24.0)
            
            Divider()
                .padding(8.0)
            
            if let winnerColor = winnerColor {
                HStack {
                    Text("👑: ")
                        .font(.body)
                    
                    Circle()
                        .frame(width: 18.0, height: 18.0)
                        .foregroundStyle(winnerColor)
                }
            } else {
                Text("Not finished")
                    .font(.body)
                    .padding([.trailing], 24.0)
            }
            
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
