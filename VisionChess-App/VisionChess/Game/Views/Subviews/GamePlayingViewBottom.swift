//
//  GamePlayingView.swift
//  VisionChess
//
//  Created by Tim Bachmann on 05.02.2025.
//

import SwiftUI

struct GamePlayingViewBottom: View {
    let viewModel: GameViewModel
    
    @State private var isScaled = false
    
    var body: some View {
        VStack {
            HStack(spacing: 12.0) {
                Image(systemName: "circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .foregroundStyle(viewModel.gameManager?.currentSide == .black ? .black : .white)
            }
            .padding()
            .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12))
        }
        .animation(.spring, value: isScaled)
    }
}
