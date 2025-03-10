/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A model that represents the current state of the game
  in the SharePlay group session.
*/

import Foundation
import GroupActivities

struct GameModel: Codable, Hashable, Sendable {
    var mode: GameMode?
    
    /// The game's current state, which includes pre-game and in-game stages.
    var stage: ActivityStage = .modeSelection
    
    /// A record of all the player's turns throughout the game, which the app updates when the player completes a turn.
    var moveHistory: [Participant.ID] = []
    
}

extension GameModel {
    /// The app's states during gameplay.
    enum GameStage: Codable, Hashable, Sendable {
        case beforePlayersTurn
        case duringPlayersTurn
        case afterPlayersTurn
    }
    
    enum ActivityStage: Codable, Hashable, Sendable {
        case modeSelection
        case sideSelection
        case inSetup
        case inGame(GameStage)
        
        var isInGame: Bool {
            if case .inGame = self {
                true
            } else {
                false
            }
        }
    }
    
    enum GameMode: Codable, Hashable, Sendable {
        case physical, mixed, virtual
        var description : String {
            switch self {
                case .physical: return "physical"
                case .mixed: return "mixed"
                case .virtual: return "virtual"
            }
          }
    }
}
