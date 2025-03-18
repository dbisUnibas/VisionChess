//
//  BoardSetupView.swift
//  VisionChess
//
//  Created by Tim Bachmann on 28.02.2025.
//

import SwiftUI

struct BoardSetupView: View {
    @Environment(AppModel.self) var appModel
    
    @State var showEndGameConfirmation: Bool = false
    
    var body: some View {
        VStack(alignment: .center, spacing: 64) {
            if appModel.activeController?.game.mode == .mixed {
                VStack(spacing: 24) {
                    Text("Place two markers on opposite corners of your board's fields.")
                        .font(.title)
                    
                    Text("Look at a your board and pinch to place a marker.")
                        .font(.subheadline)
                }
                
                Image("markerInstructions")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 86, height: 86)
            } else {
                Text("Look at a flat surface and pinch to place the board.")
                    .font(.title)
                
                Image(systemName: "arrow.down.to.line.square")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
            }
        }
        .padding()
        .visionChessToolbar()
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
}

struct BoardSetupView_Previews: PreviewProvider {
    static let appModel = AppModel()

    static var previews: some View {
        BoardSetupView()
            .environment(appModel)
            .glassBackgroundEffect()
            .frame(width: 900, height: 600)
    }
}
