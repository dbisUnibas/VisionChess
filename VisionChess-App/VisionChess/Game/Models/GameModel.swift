//
//  GameModel.swift
//  VisionChess
//
//  Created by Tim Bachmann on 12.03.2025.
//

import Foundation
import GroupActivities

struct GameModel: Codable, Hashable, Sendable {
    var mode: GameMode?
    var currentSide: PlayerModel.Side = .white
    var gameStateFen: String = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    var checkers: [ChessField] = []
    var winner: PlayerModel.Side?
    var gameMode: GameModel.GameMode? = .virtual
    var gameId: String?
    var lastKnownPosition: [ChessPiece: ChessField] = initialPosition
    var stage: ActivityStage = .modeSelection
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
        case gameOver
        
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
    
    enum OpponentStrength: String, CaseIterable, Identifiable {
        case easy = "Easy"
        case medium = "Medium"
        case hard = "Hard"
        case expert = "Expert"

        var id: String { self.rawValue }

        // Mapping to numbers 1 to 5
        var level: Int {
            switch self {
            case .easy: return 1
            case .medium: return 2
            case .hard: return 3
            case .expert: return 4
            }
        }

        // Convert from number to OpponentStrength
        static func fromLevel(_ level: Int) -> OpponentStrength? {
            switch level {
            case 1: return .easy
            case 2: return .medium
            case 3: return .hard
            case 4: return .expert
            default: return nil // Return nil if level is out of range
            }
        }
    }
}
