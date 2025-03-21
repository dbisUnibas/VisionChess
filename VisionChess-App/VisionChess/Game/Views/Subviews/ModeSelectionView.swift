//
//  ModeSelectionView.swift
//  VisionChess
//
//  Created by Tim Bachmann on 12.03.2025.
//

import SwiftUI


struct ModeSelectionView: View {
    @Environment(AppModel.self) var appModel
    
    var body: some View {
        Form {
            Section {
                HStack(alignment: .center, spacing: 32) {
                    //ModeButton(title: "Physical Game", mode: GameModel.GameMode.physical, appModel: appModel).disabled(true)
                    ModeButton(title: "Physical Board", mode: GameModel.GameMode.mixed, appModel: appModel)
                    ModeButton(title: "Virtual Board", mode: GameModel.GameMode.virtual, appModel: appModel)
                }
            } header: {
                Text("Modes")
            } footer: {
                Text("Select the mode you'd like to play in.")
            }
        }
        .frame(width: 900)
        .visionChessToolbar()
        .toolbar {
            if appModel.gameController != nil {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button("Back", systemImage: "chevron.left") {
                        appModel.gameController = nil
                    }
                }
            }
        }
    }
    
    struct ModeButton: View {
        let title: String
        let mode: GameModel.GameMode
        let appModel: AppModel
        
        var body: some View {
            Button {
                appModel.activeController?.enterTeamSelection(gameMode: mode)
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

struct ModeSelectionView_Previews: PreviewProvider {
    static let appModel = AppModel()

    static var previews: some View {
        ModeSelectionView()
            .environment(appModel)
            .glassBackgroundEffect()
            .frame(width: 900, height: 600)
    }
}
