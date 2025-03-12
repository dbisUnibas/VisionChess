//
//  WelcomeView.swift
//  VisionChess
//
//  Created by Tim Bachmann on 12.03.2025.
//

import SwiftUI
import RealityKit

struct WelcomeView: View {
    @Environment(AppModel.self) var appModel
    
    var body: some View {
        VStack {
            WelcomeBanner().offset(y: 20)
            
            Text("VisionChess").italic().font(.extraLargeTitle)
            
            Text("Welcome to VisionChess!")
            .multilineTextAlignment(.center)
            .padding(.top)
            
            Text("""
                To play, join a FaceTime call with a friend or practice on your own. \
                You'll join a side and take turns playing chess.
                """
            )
            .multilineTextAlignment(.center)
            .padding(.bottom)
            .padding(.horizontal)
            
            
            HStack(spacing: 36.0) {
                SharePlayButton("Play together!", activity: ChessGroupActivity())
                    .padding(.vertical, 20)
                
                Button("Training", systemImage: "chart.line.uptrend.xyaxis") {
                    appModel.gameController = GameController()
                }
                .tint(.gray)
            }
            
        }
        .padding()
    }
}

struct WelcomeBanner: View {
    var body: some View {
        HStack(alignment: .center, spacing: 48.0) {
            ZStack {
                Image("AppIcon/Back/Content")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 128)
                Image("AppIcon/Middle/Content")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 72)
                Image("AppIcon/Front/Content")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48)
            }
            .clipShape(.circle)
        }
        .font(.system(size: 50))
        .frame(maxHeight: .infinity)
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static let appModel = AppModel()

    static var previews: some View {
        WelcomeView()
            .environment(appModel)
            .glassBackgroundEffect()
            .frame(width: 900, height: 600)
    }
}
