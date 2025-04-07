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

struct MoveView_Previews: PreviewProvider {
    static let appModel = AppModel()

    static var previews: some View {
        MoveView()
            .environment(appModel)
            .glassBackgroundEffect()
    }
}
