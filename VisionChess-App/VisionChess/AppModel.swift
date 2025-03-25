//
//  AppModel.swift
//  VisionChess
//
//  Created by Tim Bachmann on 13.01.2025.
//

import SwiftUI
import AVFoundation

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
    
    // AUDIO
    private var audioPlayer: AVAudioPlayer?

    func playBackgroundMusic() {
        guard let url = Bundle.main.url(forResource: "relaxing-piano", withExtension: "mp3") else {
            print("Music file not found")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume = 0.12
            audioPlayer?.play()
        } catch {
            print("Audio playback error: \(error.localizedDescription)")
        }
    }
}
