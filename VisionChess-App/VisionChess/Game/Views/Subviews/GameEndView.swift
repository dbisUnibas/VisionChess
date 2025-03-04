//
//  GameOverView.swift
//  VisionChess
//
//  Created by Tim Bachmann on 05.02.2025.
//

import SwiftUI

struct GameEndView: View {
    let viewModel: GameViewModel
    
    @State private var didAppear = false
    
    var body: some View {
        
        VStack(spacing: 24) {
            Text("Game Over with Catches")
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: 24, x: 0, y: 1)
                .scaleEffect(didAppear ? 1 : 0.5)
                .opacity(didAppear ? 1 : 0)
                .blur(radius: didAppear ? 0 : 12)
                .offset(y: didAppear ? 0 : 16)
        }
        .animation(.spring(duration: 1.2), value: didAppear)
        .onAppear {
            didAppear = true
        }
    }
}
