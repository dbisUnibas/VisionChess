//
//  GamePlayingView.swift
//  VisionChess
//
//  Created by Tim Bachmann on 05.02.2025.
//

import SwiftUI
import RealityKit

struct GamePlayingViewLeft: View {
    let viewModel: GameViewModel
    
    @State private var isScaled = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12.0) {
                Text("Captured Pieces")
                    .font(.system(size: 20, design: .rounded))
                    .foregroundStyle(.white)
                
                Image(systemName: "circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.black)
            }
            .padding()
            
            ForEach(Array(viewModel.gameManager?.getDefeatedPieces(side: "black").enumerated() ?? [].enumerated()), id: \.offset) { index, model in
                Model3D(named: model)
            }
            
        }
        .animation(.spring, value: isScaled)
        .padding()
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12))
    }
}
