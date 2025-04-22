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
                    Text("Place two markers on opposite corners (top-left & top-right) of your board's fields.")
                        .font(.largeTitle)
                        .multilineTextAlignment(.center)
                    
                    Text("Look at a your board and pinch to place a marker.")
                        .font(.title)
                }
                
                Image("markerInstructions")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 152, height: 152)
            } else {
                Text("Look at a flat surface and pinch to place the board.")
                    .font(.largeTitle)
                    .multilineTextAlignment(.center)
                
                Image(systemName: "arrow.down.to.line.square")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 104, height: 104)
            }
        }
        .frame(width: 900, height: 600)
        .padding()
        .visionChessToolbar()
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
