//
//  AppModel.swift
//  VisionChess
//
//  Created by Tim Bachmann on 13.01.2025.
//

import SwiftUI

/// Maintains app-wide state
@Observable @MainActor
class AppModel {
    var sessionController: SessionController?
    var gameController: GameController?
    var activeController: GameControllerProtocol? {
        return sessionController ?? gameController
    }
    
    var viewModel: GameViewModel?
    
    var playerName: String = UserDefaults.standard.string(forKey: "player-name") ?? "" {
        didSet {
            UserDefaults.standard.set(playerName, forKey: "player-name")
            sessionController?.localPlayer.name = playerName
        }
    }
    
    var showPlayerNameAlert = false
    var isImmersiveSpaceOpen = false
        
    func initViewModel(dataSource: PlaneAnchoringDataSource) {
        self.viewModel = .init(appModel: self, dataSource: dataSource)
    }
    
}
