//
//  ModeSelectionView.swift
//  VisionChess
//
//  Created by Tim Bachmann on 10.03.2025.
//

import SwiftUI


struct ModeSelectionView: View {
    @Environment(AppModel.self) var appModel
    
    var body: some View {
        Form {
            Section {
                HStack(alignment: .center, spacing: 32) {
                    //ModeButton(title: "Physical Game", mode: GameModel.GameMode.physical, appModel: appModel).disabled(true)
                    ModeButton(title: "Physical Board", mode: GameModel.GameMode.mixed, appModel: appModel).disabled(true)
                    ModeButton(title: "Virtual Board", mode: GameModel.GameMode.virtual, appModel: appModel)
                }
            } header: {
                Text("Modes")
            } footer: {
                Text("Select the mode you'd like to play in.")
            }
        }
        .guessTogetherToolbar()
    }
    
    struct ModeButton: View {
        let title: String
        let mode: GameModel.GameMode
        let appModel: AppModel
        
        var body: some View {
            Button {
                appModel.sessionController?.enterTeamSelection(gameMode: mode)
            } label: {
                VStack(spacing: 24) {
                    Image(mode.description)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding()
                    Text(title)
                }
                .padding()
                .frame(minHeight: 250)
            }
            .buttonStyle(.plain)
            .buttonBorderShape(.roundedRectangle(radius: 24))
            .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 24))
        }
    }

}
