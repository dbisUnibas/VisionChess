/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A view that invites activity participants to join the Blue or Red team.
*/

import SwiftUI


struct TeamSelectionView: View {
    @Environment(AppModel.self) var appModel
    
    var body: some View {
        VStack {
            HStack {
                SideList(side: .white)
                SideList(side: .black)
            }
            
            // Start the game when a participant indicates they're ready.
            Button("Ready", systemImage: "checkmark") {
                appModel.sessionController?.startSetup()
            }
            .tint(.green)
            .disabled(whiteAndBlackSidesAreEmpty)
        }
        .padding()
        .guessTogetherToolbar()
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading) {
                Button("Back", systemImage: "chevron.left") {
                    appModel.sessionController?.endGame()
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
            return true
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
                        appModel.sessionController?.joinTeam(side)
                    }
                    .foregroundStyle(side.color.gradient)
                } else {
                    Button("Leave Side", systemImage: "person.fill.badge.minus") {
                        appModel.sessionController?.joinTeam(nil)
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
            return true
        }
    }
    
    func playersOnTeam(_ team: PlayerModel.Side) -> [PlayerModel] {
        guard let sessionController = appModel.sessionController else {
            return []
        }
        
        return sessionController.players.values.lazy.filter { player in
            player.side == team && !player.name.isEmpty
        }
        .sorted(using: KeyPathComparator(\.id))
    }
}
