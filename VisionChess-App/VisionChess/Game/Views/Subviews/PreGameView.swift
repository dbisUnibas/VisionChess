//
//  PreGameView.swift
//  VisionChess
//
//  Created by Tim Bachmann on 05.02.2025.
//

import SwiftUI

struct PreGameView: View {
    let viewModel: GameViewModel
    
    @State private var amount: Double = 1
    @State private var didAppear = false
    
    var body: some View {
        VStack(spacing: -16) {
            titleView
            
            VStack(spacing: 24) {
//                Text("Highscore: \(viewModel.gameManager.highscore)")
//                    .foregroundStyle(.white)
//                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
//                    .shadow(color: .black.opacity(0.2), radius: 24, x: 0, y: 1)
//                    .scaleEffect(didAppear ? 1 : 0.5)
//                    .opacity(didAppear ? 1 : 0)
//                    .blur(radius: didAppear ? 0 : 12)
//                    .offset(y: didAppear ? 0 : 16)
                
                Button {
                    viewModel.switchViewState(to: .inModeSelection)
                } label: {
                    Text("Start")
                }
                .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 24))
                .frame(minWidth: 128)
                .scaleEffect(didAppear ? 1 : 0.5)
                .opacity(didAppear ? 1 : 0)
                .blur(radius: didAppear ? 0 : 12)
                .offset(y: didAppear ? 0 : 24)
            }
            .animation(.easeInOut(duration: 2), value: didAppear)
        }
        .onAppear {
            didAppear = true
        }
    }
    
    @ViewBuilder
    var titleView: some View {
        VStack {
            Text(attributedTitle)
                .font(.system(size: 64, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: 24, x: 0, y: 1)
                .frame(width: 400, height: 200)
                .textRenderer(TitleTextRenderer(strength: amount, frequency: 0.5))
                .onAppear {
                    withAnimation(.easeInOut(duration: 2)) {
                        amount = 0
                    }
                }
        }
        .scaleEffect(didAppear ? 0.95 : 1.0)
        .opacity(didAppear ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: didAppear)
    }
    
    var attributedTitle: AttributedString {
        var attributedString = AttributedString("Vision Chess")
        
        // Apply regular font to "Vision"
        if let range = attributedString.range(of: "Vision") {
            attributedString[range].font = .system(size: 64, weight: .heavy)
        }
        
        // Apply bold font to "Chess"
        if let range = attributedString.range(of: "Chess") {
            attributedString[range].font = .system(size: 64, weight: .light)
        }
        
        return attributedString
    }
}

struct TitleTextRenderer: TextRenderer {
    var strength: Double
    var frequency: Double

    var animatableData: Double {
        get { strength }
        set { strength = newValue }
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        let stepDelay: TimeInterval = 0.15
        for line in layout {
            for run in line {
                for (index, glyph) in run.enumerated() {
                    let glyphEffectStrength = strength - (stepDelay * Double(index) / Double(run.count))
                    let offsetValue = 10 * glyphEffectStrength
                    let yOffset = offsetValue * sin(Double(index) * frequency)
                    var copy = context

                    copy.translateBy(x: 0, y: yOffset)
                    copy.addFilter(.blur(radius: 10 * glyphEffectStrength))
                    copy.opacity = 1 - (0.5 * glyphEffectStrength)
                    copy.draw(glyph, options: .disablesSubpixelQuantization)
                }
            }
        }
    }
}
