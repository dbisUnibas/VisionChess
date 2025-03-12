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
            VStack(spacing: 64) {
                Text("Look at a flat surface and pinch to place the board.")
                    .font(.title)
                
                Image(systemName: "arrow.down.to.line.square")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
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

#Preview {
    BoardSetupView()
}
