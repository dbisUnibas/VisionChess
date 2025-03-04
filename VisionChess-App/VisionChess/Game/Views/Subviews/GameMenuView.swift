//
//  GameMenuView.swift
//  VisionChess
//
//  Created by Tim Bachmann on 10.02.2025.
//

import SwiftUI

struct GameMenuView: View {
    let viewModel: GameViewModel
    
    var body: some View {
            VStack(spacing: 32) {
                Text("Which type of opponent do you want to play against?")
                    .font(.largeTitle)
                
                HStack(alignment: .center, spacing: 32) {
                    OpponentButton(viewModel: viewModel, title: "SharePlay", image: "shareplay", action: { viewModel.toggleSharePlay() })
                    OpponentButton(viewModel: viewModel, title: "Computer Opponent", image: "sparkles", action: { viewModel.switchViewState(to: .setup)})
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

struct OpponentButton: View {
    let viewModel: GameViewModel
    let title: String
    let image: String
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 24) {
                Image(systemName: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)
                    .padding()
                Text(title)
            }
            .padding()
            .frame(minWidth: 230)
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.roundedRectangle(radius: 24))
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 24))
    }
}
