//
//  GamePlayingView.swift
//  VisionChess
//
//  Created by Tim Bachmann on 12.03.2025.
//

import SwiftUI
import RealityKitContent
import RealityKit

struct GameOverView: View {
    @Environment(AppModel.self) var appModel
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    
    @State private var didAppear = false
    
    var body: some View {
        VStack(spacing: 24) {
            if (appModel.activeController?.game.winner != nil && appModel.activeController?.game.winner == appModel.activeController?.localPlayer.side) {
                if appModel.activeController?.game.mode == .tutorial {
                    Text("Checkmate 🎉")
                        .font(.system(size: 42, weight: .heavy))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 24, x: 0, y: 1)
                        .scaleEffect(didAppear ? 1 : 0.5)
                        .opacity(didAppear ? 1 : 0)
                        .blur(radius: didAppear ? 0 : 12)
                        .offset(y: didAppear ? 0 : 16)
                        .padding()
                    
                    Spacer()
                        .frame(height: 32)
                    
                    TeamGameOverViewTrophy()
                    
                    Spacer()
                        .frame(height: 32)
                    
                    Text("Great job! You successfully completed the tutorial!\n You are now ready to play the game!")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 24, x: 0, y: 1)
                        .scaleEffect(didAppear ? 1 : 0.5)
                        .opacity(didAppear ? 1 : 0)
                        .blur(radius: didAppear ? 0 : 12)
                        .offset(y: didAppear ? 0 : 16)
                        .padding()
                } else {
                    Text("Checkmate 🎉")
                        .font(.system(size: 42, weight: .heavy))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 24, x: 0, y: 1)
                        .scaleEffect(didAppear ? 1 : 0.5)
                        .opacity(didAppear ? 1 : 0)
                        .blur(radius: didAppear ? 0 : 12)
                        .offset(y: didAppear ? 0 : 16)
                        .padding()
                    
                    Spacer()
                        .frame(height: 32)
                    
                    TeamGameOverViewTrophy()
                    
                    Spacer()
                        .frame(height: 32)
                    
                    Text("Great job!")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 24, x: 0, y: 1)
                        .scaleEffect(didAppear ? 1 : 0.5)
                        .opacity(didAppear ? 1 : 0)
                        .blur(radius: didAppear ? 0 : 12)
                        .offset(y: didAppear ? 0 : 16)
                        .padding()
                }
            } else {
                Text("Checkmate...")
                    .font(.system(size: 42, weight: .heavy))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 24, x: 0, y: 1)
                    .scaleEffect(didAppear ? 1 : 0.5)
                    .opacity(didAppear ? 1 : 0)
                    .blur(radius: didAppear ? 0 : 12)
                    .offset(y: didAppear ? 0 : 16)
                    .padding()
                
                Spacer()
                    .frame(height: 32)
                
                TeamGameOverViewCheckmate(team: appModel.activeController?.localPlayer.side ?? .white)
                
                Spacer()
                    .frame(height: 32)
                
                Text("Better luck next time!")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 24, x: 0, y: 1)
                    .scaleEffect(didAppear ? 1 : 0.5)
                    .opacity(didAppear ? 1 : 0)
                    .blur(radius: didAppear ? 0 : 12)
                    .offset(y: didAppear ? 0 : 16)
                    .padding()
            }
            
            Button("Quit", systemImage: "xmark") {
                appModel.activeController?.endGame()
                appModel.destroyController()
            }
            .padding()
        }
        .animation(.spring(duration: 1.2), value: didAppear)
        .onAppear {
            didAppear = true
            
            if let activeController = appModel.activeController {
                if activeController.localPlayer.side == activeController.game.winner {
                    activeController.playSoundEffect(SFX.win)
                } else {
                    activeController.playSoundEffect(SFX.lose)
                }
            }
            
        }
        .padding()
        .visionChessToolbar()
    }
}

struct TeamGameOverViewTrophy: View {
    @Environment(AppModel.self) var appModel
    
    var body: some View {
        VStack(spacing: 12) {
            Model3D(named: "trophy", bundle: realityKitContentBundle)
                .scaleEffect(x: 0.05, y: 0.05, z: 0.05)
                .frame(depth: 64, alignment: .center)
        }
        .frame(maxWidth: 900, maxHeight: 50)
        .padding()
        
    }
}

struct TeamGameOverViewCheckmate: View {
    @Environment(AppModel.self) var appModel
    let team: PlayerModel.Side
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Model3D(named: "winner_\(team.rawValue == "white" ? "black" : "white")", bundle: realityKitContentBundle)
                    .frame(depth: 64, alignment: .front)
            }
        }
        .frame(maxWidth: 900, maxHeight: 50)
        .padding()
        
    }
}

struct GameOverView_Previews: PreviewProvider {
    static let appModel = AppModel()

    static var previews: some View {
        GameOverView()
            .environment(appModel)
            .glassBackgroundEffect()
            .frame(width: 900, height: 600)
    }
}
