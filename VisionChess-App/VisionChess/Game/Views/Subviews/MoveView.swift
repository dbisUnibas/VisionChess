//
//  MoveView.swift
//  VisionChess
//
//  Created by Tim Bachmann on 31.03.2025.
//

import SwiftUI

struct MoveView: View {
    @Environment(AppModel.self) var appModel
    
    
    var body: some View {
        if true { // appModel.activeController?.game.mode == .review {
            ReviewNavigationView()
        } else {
            MoveDetectionView()
        }
    }
}

struct MoveDetectionView: View {
    @Environment(AppModel.self) var appModel

    var body: some View {
        if let alert = appModel.activeController?.alert {
            VStack(spacing: 18) {
                Text(alert)
                    .foregroundColor(.orange)
                
                Button("Proceed", systemImage: "checkmark") {
                    appModel.activeController?.resetAlert()
                }
            }
            .padding()
        } else {
            if appModel.activeController?.localPlayer.isPlaying == true && appModel.activeController?.currentMoveEstimate == nil {
                Button(action: {}) {
                    HStack {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                        Text("Detecting move...")
                    }
                }
                .disabled(true)
                .padding()
            } else if appModel.activeController?.localPlayer.isPlaying == true && appModel.activeController?.currentMoveEstimate != nil {
                
                Button("Apply Move \(appModel.activeController?.currentMoveEstimate ?? "")", systemImage: "checkmark") {
                    appModel.activeController?.applyPhysicalMove()
                }
                .tint(.green)
                .padding()
                .disabled(
                    appModel.activeController?.currentMoveEstimate == nil
                    || appModel.activeController?.moveRequestPending == true
                    
                )
            } else {
                Button(action: {}) {
                    HStack {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                        Text("Waiting for opponent...")
                    }
                }
                .disabled(true)
                .padding()
            }
        }
    }
}

struct ReviewNavigationView: View {
    @Environment(AppModel.self) var appModel

    var body: some View {
            
        HStack(spacing: 32) {
            Button(action: {
                appModel.reviewController?.previousMove()
            }) {
                Image(systemName: "chevron.backward")
            }
            .disabled(appModel.reviewController?.game.stage != .inGame(.beforePlayersTurn) || appModel.reviewController!.currentMoveIndex == 0)
            
            Button(action: {}) {
                HStack {
                    if appModel.reviewController?.game.moveHistory.count ?? 0 > appModel.reviewController?.currentMoveIndex ?? 0 {
                        Text(appModel.reviewController?.game.moveHistory[appModel.reviewController?.currentMoveIndex ?? 0] ?? "No Move left")
                    }
                }
            }
            .disabled(true)
            .padding([.leading, .trailing], 24.0)
            
            Button(action: {
                appModel.reviewController?.nextMove()
            }) {
                Image(systemName: "chevron.forward")
            }
            .disabled(appModel.reviewController?.game.stage != .inGame(.beforePlayersTurn) || appModel.reviewController?.game.moveHistory.count ?? 0 <= appModel.reviewController?.currentMoveIndex ?? 0)
        }
        .padding()
    }
}

struct MoveView_Previews: PreviewProvider {
    static let appModel = AppModel()

    static var previews: some View {
        MoveView()
            .environment(appModel)
            .glassBackgroundEffect()
    }
}
