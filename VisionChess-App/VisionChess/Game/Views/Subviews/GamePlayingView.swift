//
//  GamePlayingView.swift
//  VisionChess
//
//  Created by Tim Bachmann on 05.02.2025.
//

import SwiftUI
import RealityKit

struct GamePlayingView: View {
    @Binding var viewModel: GameViewModel
    
    @State private var isScaled = false
    
    var body: some View {
        Text(viewModel.errorMessage ?? "")
            .font(.system(size: 20, design: .rounded))
            .foregroundStyle(.white)
            .animation(.spring, value: isScaled)
            .padding()
            .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12))
    }
}
