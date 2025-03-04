//
//  GameManager.swift
//  VisionChess
//
//  Created by Tim Bachmann on 05.02.2025.
//

import SwiftUI
import UIKit
import Combine
import Vision
import OpenAPIClient
import RealityKit

struct GameOverData: Equatable {
    let score: Int
    let isNewHighscore: Bool
}

// MARK: - GameManager
@Observable
class GameManager {
    var viewModel: GameViewModel
    private(set) var gameStateFen: String = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    private(set) var gameMode: GameMode? = .virtual
    private(set) var gameId: String?
    private(set) var currentSide: Side? = .white
    
    public let scoreChangeSubject: PassthroughSubject<Int, Never> = .init()
    var onGameOver: ((GameOverData) -> Void)?
    
    var lastKnownPosition: [ChessPiece: ChessField]
    
    init(viewModel: GameViewModel) {
        self.viewModel = viewModel
        lastKnownPosition = initialPosition
    }
    
    func startGame() {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString
        if let deviceId = deviceId {
            let request = GameRequest(white: deviceId, black: "", opponent: GameRequest.Opponent.init(rawValue: gameMode!.description.uppercased())!)
            GamesAPI.gamesPost(gameRequest: request, completion: { response, error in
                if let error = error {
                    print("Error: \(error.localizedDescription)")
                    return
                }
                print(response ?? "response")
                
                self.gameId = response
            })
        }
    }
    
    // Call this function to update the manager with the latest predictions
    func update(predictions: [ChessPieceDetectionManager.PredictionResult]) {
        
        let currentTimeStamp = Date()
        
        // Check if the ball is currently detected in the air
        let isBallCurrentlyInAir: Bool = {
            guard let ballInAirPrediction = predictions.first(where: { $0.isBallInAir }) else {
                return false
            }
            return ballInAirPrediction.confidence > 0.65
        }()
    }
    
    func reset() {
        gameStateFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        currentSide = .white
    }
    
    func setGameMode(mode: GameMode) {
        gameMode = mode
    }
    
    func getGameMode() -> GameMode? {
        return gameMode
    }
    
    func getCurrentSide() -> Side? {
        return currentSide
    }
    
    func updateGameState() {
        guard let gameId = gameId else {
            return
        }
        GamesAPI.gamesIdGet(id: gameId) { response, error in
            guard error == nil else {
                print("Error fetching game state: \(error!.localizedDescription)")
                return
            }
            print(response ?? "")
            self.gameStateFen = response!.gameState
        }
    }
    
    func pieceAt(field: String) -> ChessPieceFen? {
        let parts = gameStateFen.split(separator: " ")
        guard let boardState = parts.first else { return nil }
        
        let ranks = boardState.split(separator: "/")
        guard ranks.count == 8 else { return nil }
        
        let file = field.first!
        let rank = field.last!
        
        guard let rankIndex = "87654321".firstIndex(of: rank),
              let fileIndex = "abcdefgh".firstIndex(of: file) else { return nil }
        
        let row = ranks[rankIndex.utf16Offset(in: "87654321")]
        
        var expandedRow = ""
        for char in row {
            if let digit = char.wholeNumberValue {
                expandedRow += String(repeating: ".", count: digit)
            } else {
                expandedRow.append(char)
            }
        }
        
        let fileOffset = fileIndex.utf16Offset(in: "abcdefgh")
        let expandedIndex = expandedRow.index(expandedRow.startIndex, offsetBy: fileOffset)
        let pieceChar = expandedRow[expandedIndex]
        
        return ChessPieceFen(rawValue: String(pieceChar))
    }
    
    func getBestMove(completion: @escaping (String?) -> Void) {
        guard let gameId = gameId else {
            completion(nil)
            return
        }
        
        GamesAPI.gamesIdBestMoveGet(id: gameId) { response, error in
            guard error == nil else {
                print("Error fetching best move: \(error!.localizedDescription)")
                completion(nil)
                return
            }
            print(response ?? "")
            completion(response)
        }
    }
    
    func move(piece: ChessPiece, to: ChessField, completion: @escaping (Bool) -> Void) {
        guard let gameId = gameId else {
            viewModel.errorMessage = "Move not valid! Please try another move."
            completion(false)
            return
        }
        let from = self.lastKnownPosition[piece]
        if let from = from {
            if from != to {
                let moveRequest = MoveRequest(move: "\(from)\(to)")
                
                GamesAPI.gamesIdMovePost(id: gameId, moveRequest: moveRequest) { response, error in
                    guard error == nil && !(response?.contains("not valid") ?? true) else {
                        //print("Error fetching best move: \(error!.localizedDescription)")
                        completion(false)
                        return
                    }
                    
                    self.lastKnownPosition[piece] = to
                    self.updateGameState()
                    self.endTurn()
                    print(response ?? "")
                    completion(true)
                }
            } else {
                completion(true)
            }
        } else {
            completion(true)
        }
    }
    
    func getPieceByField(field: ChessField) -> ChessPiece? {
        return lastKnownPosition.first { $0.value == field }?.key
    }
    
    func endTurn() {
        let nextSide: Side = (self.currentSide == .white) ? .black : .white
        self.currentSide = nextSide
        if (nextSide == .black) {
            self.getBestMove() { move in
                if let move = move {
                    let move = move.split(separator: ",")[0]
                    guard move.count == 4 else {
                        return
                    }
                    
                    let from = ChessField(rawValue: String(move.prefix(2)))
                    let to = ChessField(rawValue: String(move.suffix(2)))
                    
                    
                    if let from = from, let to = to {
                        let pieceToMove = self.getPieceByField(field: from)
                        let chessPieceEntity = self.viewModel.utilityEntities.contentEntity.findEntity(named: pieceToMove!.rawValue)
                        let chessFieldEntity = self.viewModel.utilityEntities.contentEntity.findEntity(named: to.rawValue)
                        
                        if let pieceToMove = pieceToMove, let chessPieceEntity = chessPieceEntity, let chessFieldEntity = chessFieldEntity {
                            self.move(piece: pieceToMove, to: to) { response in
                                guard response == true else {
                                    return
                                }
                                self.viewModel.currentlyMovingChessPiece = chessPieceEntity
                                self.animateMove(piece: chessPieceEntity, field: chessFieldEntity)
                                
                                self.getBestMove { move in
                                    if let move = move {
                                        let move = move.split(separator: ",")[0]
                                        guard move.count == 4 else {
                                            return
                                        }
                                        
                                        let from = ChessField(rawValue: String(move.prefix(2)))
                                        let to = ChessField(rawValue: String(move.suffix(2)))
                                        
                                        if let from = from, let to = to {
                                            let chessFieldFromEntity = self.viewModel.utilityEntities.contentEntity.findEntity(named: from.rawValue)
                                            let chessFieldToEntity = self.viewModel.utilityEntities.contentEntity.findEntity(named: to.rawValue)
                                            
                                            if let chessFieldToEntity = chessFieldToEntity, let chessFieldFromEntity = chessFieldFromEntity {
                                                chessFieldFromEntity.components[OpacityComponent.self]?.opacity = 0.4
                                                chessFieldToEntity.components[OpacityComponent.self]?.opacity = 0.4
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func animateMove(piece: Entity, field: Entity) {
        piece.components[PhysicsBodyComponent.self]?.isAffectedByGravity = false

        // Step 1: Move up slightly
        let upTransform = Transform(translation: SIMD3(0, 0.05, 0))
        piece.move(to: upTransform, relativeTo: piece, duration: 0.5, timingFunction: .easeIn)
        let finalTranslation = field.transform.translation + SIMD3(0, 0.05, 0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Step 2: Move to the target field
            let finalTransform = Transform(scale: piece.transform.scale,
                                           rotation: piece.transform.rotation,
                                           translation: finalTranslation)
            piece.move(to: finalTransform, relativeTo: piece.parent!, duration: 1.0, timingFunction: .linear)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.01) {
                
                // Step 3: Move down slightly for a landing effect
                let downTransform = Transform(translation: SIMD3(0, -0.05, 0))
                piece.move(to: downTransform, relativeTo: piece, duration: 0.5, timingFunction: .easeOut)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // Step 4: Restore gravity
                    piece.components[PhysicsBodyComponent.self]?.isAffectedByGravity = true
                    field.components[OpacityComponent.self]?.opacity = 0.0
                    self.viewModel.currentTargetField = []
                    self.viewModel.currentlyMovingChessPiece = nil
                    self.viewModel.currentlyMovingChessPieceInitialField = nil
                    self.viewModel.currentlyMovingChessPieceCollisionSubscription?.cancel()
                    self.viewModel.currentlyMovingChessPieceCollisionSubscription = nil
                    self.viewModel.currentlyMovingChessPieceCollisionSubscriptionEnd?.cancel()
                    self.viewModel.currentlyMovingChessPieceCollisionSubscriptionEnd = nil
                    self.viewModel.deactivateInput()
                }
            }
        }
    }
    
    func getDefeatedPieces(side: String) -> [String] {
        var defeatedPieces: [String] = []
        
        self.lastKnownPosition.forEach { piece, field in
            if field == ChessField.defeated && piece.rawValue.hasPrefix(side) {
                if piece == ChessPiece.whiteQueen && piece == ChessPiece.blackQueen {
                    if let model = chessPieceToModel[piece.rawValue] {
                        defeatedPieces.append(model)
                    }
                } else {
                    if let model = chessPieceToModel[String(piece.rawValue.dropLast())] {
                        defeatedPieces.append(model)
                    }
                }
            }
        }
        return defeatedPieces
    }
}
