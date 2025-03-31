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
        Button("Apply Move \(appModel.activeController?.currentMoveEstimate ?? "")", systemImage: "checkmark") {
            appModel.activeController?.applyPhysicalMove()
        }
        .tint(.green)
        .padding()
        .disabled(appModel.activeController?.currentMoveEstimate == nil || appModel.activeController?.moveRequestPending == true)
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
