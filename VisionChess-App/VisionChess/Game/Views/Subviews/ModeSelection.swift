//
//  ModeSelection.swift
//  VisionChess
//
//  Created by Tim Bachmann on 13.01.2025.
//

import SwiftUI

struct ModeSelection: View {
    let viewModel: GameViewModel
    
    var body: some View {
            VStack(spacing: 32) {
                Text("How do you want to play?")
                    .font(.largeTitle)
                
                HStack(alignment: .center, spacing: 32) {
                    ModeButton(viewModel: viewModel, title: "Physical Game", mode: GameMode.physical).disabled(true)
                    ModeButton(viewModel: viewModel, title: "Physical Board / Virtual Opponent", mode: GameMode.mixed).disabled(true)
                    ModeButton(viewModel: viewModel, title: "Virtual Board / Virtual Opponent", mode: GameMode.virtual)
                }
                
                Button {
                    viewModel.goToPreviousState()
                } label: {
                    HStack {
                        Image(systemName: "chevron.backward")
                        Text("Back")
                            .font(.footnote)
                    }
                    
                }
                .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 24))
            }
            .padding()
    }
}

struct ModeButton: View {
    let viewModel: GameViewModel
    let title: String
    let mode: GameMode
    
    var body: some View {
        Button {
            viewModel.gameManager?.setGameMode(mode: mode)
            viewModel.switchViewState(to: .inGameMenu)
            
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
