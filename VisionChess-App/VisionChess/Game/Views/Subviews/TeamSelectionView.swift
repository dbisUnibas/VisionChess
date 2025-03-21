//
//  TeamSelectionView.swift
//  VisionChess
//
//  Created by Tim Bachmann on 12.03.2025.
//

import SwiftUI


struct TeamSelectionView: View {
    @Environment(AppModel.self) var appModel
    @State private var selectedStrength: GameModel.OpponentStrength = .medium
    
    var body: some View {
        VStack {
            HStack {
                SideList(side: .white)
                SideList(side: .black)
            }
            
            Spacer()
            
            if appModel.gameController != nil {
                OpponentStrengthSelector(selectedStrength: $selectedStrength)
                    .padding(24)
                    .onChange(of: selectedStrength) { oldValue, newValue in
                        appModel.gameController?.opponentStrength = newValue
                    }
            }
            
            // Start the game when a participant indicates they're ready.
            Button("Ready", systemImage: "checkmark") {
                appModel.activeController?.startSetup()
            }
            .tint(.green)
            .disabled(whiteAndBlackSidesAreEmpty)
        }
        .frame(width: 900)
        .padding()
        .visionChessToolbar()
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading) {
                Button("Back", systemImage: "chevron.left") {
                    appModel.activeController?.endGame()
                }
            }
        }
    }
    
    var whiteAndBlackSidesAreEmpty: Bool {
        if let sessionController = appModel.sessionController {
            let containsPlayerWithATeam = sessionController.players.values.contains {
                $0.side != nil
            }
            return !containsPlayerWithATeam
            
        } else {
            if let gameController = appModel.gameController {
                return gameController.localPlayer.side == nil
            } else {
                return true
            }
        }
    }
}

struct SideList: View {
    @Environment(AppModel.self) var appModel
    
    let side: PlayerModel.Side
    
    var body: some View {
        List {
            Section(side.name) {
                ForEach(playersOnTeam(side)) { player in
                    Text(player.name)
                }
                
                if appModel.sessionController?.localPlayer.side != side && sideIsEmpty(side: side) {
                    Button("Select \(side.name)", systemImage: "person.fill.badge.plus") {
                        appModel.activeController?.joinTeam(side)
                    }
                    .foregroundStyle(side.color.gradient)
                } else {
                    Button("Leave Side", systemImage: "person.fill.badge.minus") {
                        appModel.activeController?.joinTeam(nil)
                    }
                    .foregroundStyle(.tertiary)
                }
            }
        }
    }
    
    func sideIsEmpty(side: PlayerModel.Side) -> Bool {
        if let sessionController = appModel.sessionController {
            let containsPlayerWithSide = sessionController.players.values.contains {
                $0.side == side
            }
            
            return !containsPlayerWithSide
        } else {
            if let gameController = appModel.gameController {
                return gameController.localPlayer.side != side
            } else {
                return true
            }
        }
    }
    
    func playersOnTeam(_ team: PlayerModel.Side) -> [PlayerModel] {
        guard let sessionController = appModel.sessionController else {
            guard let gameController = appModel.gameController else {
                return []
            }
            
            if gameController.localPlayer.side == team {
                return [gameController.localPlayer]
            } else {
                return []
            }
        }
        
        return sessionController.players.values.lazy.filter { player in
            player.side == team && !player.name.isEmpty
        }
        .sorted(using: KeyPathComparator(\.id))
    }
}

struct OpponentStrengthSelector: View {
    @Binding var selectedStrength: GameModel.OpponentStrength

    var body: some View {
        VStack {
            Text("Select Difficulty")
                .font(.headline)
            
            Picker("Opponent Strength", selection: $selectedStrength) {
                ForEach(GameModel.OpponentStrength.allCases) { strength in
                    Text(strength.rawValue).tag(strength)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
        }
    }
}

struct TeamSelectionView_Previews: PreviewProvider {
    static let appModel = AppModel()

    static var previews: some View {
        TeamSelectionView()
            .environment(appModel)
            .glassBackgroundEffect()
            .frame(width: 900, height: 600)
    }
}
