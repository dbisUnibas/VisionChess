//
//  GameController.swift
//  VisionChess
//
//  Created by Tim Bachmann on 12.03.2025.
//

import Observation
import Foundation
import SwiftUI
import OpenAPIClient
import RealityKit

@Observable @MainActor
final class GameController: GameControllerProtocol {
    var opponentStregth: GameModel.OpponentStrength = .medium
    
    var currentTargetField: [Entity] = []
    var currentlyMovingChessPiece: Entity? = nil
    var currentlyMovingChessPieceCollisionSubscription: EventSubscription? = nil
    var currentlyMovingChessPieceCollisionSubscriptionEnd: EventSubscription? = nil
    
    var contentEntity = Entity()
    var deviceLocation: Entity = .init()
    var raycastOrigin: Entity = .init()
    var placementLocation: Entity = .init()
    
    init() {
        contentEntity.addChild(placementLocation)
        deviceLocation.addChild(raycastOrigin)
        
        // Angle raycasts 15 degrees down.
        let raycastDownwardAngle = 15.0 * (Float.pi / 180)
        raycastOrigin.orientation = simd_quatf(angle: -raycastDownwardAngle, axis: [1.0, 0.0, 0.0])
    }
    

    /// When the user is gazing at a valid plane target, insert the placement cursor
    var planeToProjectOnFound = false {
        didSet {
            if planeToProjectOnFound {
                contentEntity.addChild(placementLocation)
            } else {
                placementLocation.removeFromParent()
            }
        }
    }
    
    var game: GameModel {
        get {
            gameSyncStore.game
        }
        set {
            if newValue != gameSyncStore.game {
                gameSyncStore.game = newValue
            }
        }
    }
    
    var localPlayer = PlayerModel(id: UUID(), name: "You")
    
    var gameSyncStore = GameSyncStore() {
        didSet {
            gameStateChanged()
        }
    }
    
    func setPlaneToProjectOnFound(value: Bool) {
        planeToProjectOnFound = value
    }
    
    func setPlacementLocationTransform(value: Transform) {
        placementLocation.transform = value
    }
    
    func setCurrentlyMovingChessPiece(entity: Entity) {
        currentlyMovingChessPiece = entity
    }

    func enterTeamSelection(gameMode: GameModel.GameMode) {
        game.stage = .sideSelection
        game.mode = gameMode
        game.moveHistory.removeAll()
    }
    
    func joinTeam(_ side: PlayerModel.Side?) {
        localPlayer.side = side
    }
    
    func startSetup() {
        game.stage = .inSetup
    }
    
    func startGame(opponentStrength: GameModel.OpponentStrength) {
        game.stage = .inGame(.beforePlayersTurn)
        
        let deviceId = UIDevice.current.identifierForVendor?.uuidString
        if let deviceId = deviceId {
            let request = GameRequest(white: deviceId, black: "", opponent: GameRequest.Opponent.init(rawValue: game.gameMode!.description.uppercased())!, opponentStrength: opponentStrength.level)
            GamesAPI.gamesPost(gameRequest: request, completion: { response, error in
                if let error = error {
                    print("Error: \(error.localizedDescription)")
                    return
                }
                print(response ?? "response")
                
                self.game.gameId = response
                self.beginTurn()
            })
        }
    }
    
    func beginTurn() {
        game.stage = .inGame(.duringPlayersTurn)
        
        if !game.checkers.isEmpty {
            game.checkers.forEach { checker in
                let checkerFieldEntity = self.contentEntity.findEntity(named: checker.rawValue)
                
                if let checkerFieldEntity = checkerFieldEntity {
                    checkerFieldEntity.components[OpacityComponent.self]?.opacity = 1
                }
            }
        }
        
        if (game.currentSide != localPlayer.side) {
            self.getBestMove() { move in
                if let move = move {
                    let move = move.split(separator: ",")[0]
                    guard move != "(none)" else {
                        // Checkmate
                        self.setWinner(side: self.game.currentSide == .white ? .black : .white)
                        return
                    }
                    
                    let from = ChessField(rawValue: String(move.prefix(2)))
                    let to = ChessField(rawValue: String(move.suffix(2)))
                    
                    
                    if let from = from, let to = to {
                        let pieceToMove = self.getPieceByField(field: from)
                        let chessPieceEntity = self.contentEntity.findEntity(named: pieceToMove!.rawValue)
                        let chessFieldEntity = self.contentEntity.findEntity(named: to.rawValue)
                        
                        if let pieceToMove = pieceToMove, let chessPieceEntity = chessPieceEntity, let chessFieldEntity = chessFieldEntity {
                            self.move(piece: pieceToMove, to: to) { response in
                                guard response == true else {
                                    return
                                }
                                self.currentlyMovingChessPiece = chessPieceEntity
                                self.animateMove(piece: chessPieceEntity, field: chessFieldEntity)
                            }
                        }
                    }
                }
            }
        } else {
            self.activateInput()
            
            self.getBestMove { move in
                if let move = move {
                    let move = move.split(separator: ",")[0]
                    guard move != "(none)" else {
                        // Checkmate
                        self.setWinner(side: self.game.currentSide == .white ? .black : .white)
                        return
                    }
                    
                    let from = ChessField(rawValue: String(move.prefix(2)))
                    let to = ChessField(rawValue: String(move.suffix(2)))
                    
                    if let from = from, let to = to {
                        let chessFieldFromEntity = self.contentEntity.findEntity(named: from.rawValue)
                        let chessFieldToEntity = self.contentEntity.findEntity(named: to.rawValue)
                        
                        if let chessFieldToEntity = chessFieldToEntity, let chessFieldFromEntity = chessFieldFromEntity {
                            chessFieldFromEntity.components[OpacityComponent.self]?.opacity = 0.4
                            chessFieldToEntity.components[OpacityComponent.self]?.opacity = 0.4
                        }
                    }
                }
            }
        }
        
    }
    
    func endTurn() {
        guard game.stage.isInGame else {
            return
        }
        
        currentTargetField = []
        currentlyMovingChessPiece = nil
        currentlyMovingChessPieceCollisionSubscription?.cancel()
        currentlyMovingChessPieceCollisionSubscription = nil
        currentlyMovingChessPieceCollisionSubscriptionEnd?.cancel()
        currentlyMovingChessPieceCollisionSubscriptionEnd = nil
        deactivateInput()
        hideAllFieldEntities()
        
        // self.setWinner(side: self.game.currentSide)
        
        game.stage = .inGame(.beforePlayersTurn)
        game.currentSide = game.currentSide == .white ? .black : .white
        
        print(game.currentSide)
        self.beginTurn()
    }
    
    func setWinner(side: PlayerModel.Side) {
        game.winner = side
        game.stage = .gameOver
    }
    
    func endGame() {
        game.stage = .modeSelection
        game.gameStateFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        game.currentSide = .white
    }
    
    func gameStateChanged() {
        if game.stage == .modeSelection {
//            localPlayer.isPlaying = false
//            localPlayer.score = 0
        }
    }
    
    func updateGameState() {
        guard let gameId = game.gameId else {
            return
        }
        GamesAPI.gamesIdGet(id: gameId) { response, error in
            guard error == nil else {
                print("Error fetching game state: \(error!.localizedDescription)")
                return
            }
            print(response ?? "")
            self.game.gameStateFen = response?.gameState ?? ""
            self.game.checkers = response?.checkers.compactMap { ChessField(rawValue: $0) } ?? []
            self.endTurn()
        }
    }
    
    func pieceAt(field: String) -> ChessPieceFen? {
        let parts = game.gameStateFen.split(separator: " ")
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
    
    func getFieldEntityFromChessPieceEntity(_ chessPieceEntity: Entity) -> Entity? {
        let chessPiece = ChessPiece(rawValue: chessPieceEntity.name)
        
        if let chessPiece = chessPiece, let field = game.lastKnownPosition[chessPiece] {
            return contentEntity.findEntity(named: field.rawValue)
        } else {
            return nil
        }
    }
    
    func getBestMove(completion: @escaping (String?) -> Void) {
        guard let gameId = game.gameId else {
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
        guard let gameId = game.gameId else {
            completion(false)
            return
        }
        let from = game.lastKnownPosition[piece]
        if let from = from {
            if from != to {
                let moveRequest = MoveRequest(move: "\(from)\(to)")
                
                GamesAPI.gamesIdMovePost(id: gameId, moveRequest: moveRequest) { response, error in
                    guard error == nil else {
                        print("Error fetching best move: \(error!.localizedDescription)")
                        completion(false)
                        return
                    }
                    
                    self.game.lastKnownPosition[piece] = to
                    self.updateGameState()
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
        return game.lastKnownPosition.first { $0.value == field }?.key
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
                    self.currentTargetField = []
                    self.currentlyMovingChessPiece = nil
                    self.currentlyMovingChessPieceCollisionSubscription?.cancel()
                    self.currentlyMovingChessPieceCollisionSubscription = nil
                    self.currentlyMovingChessPieceCollisionSubscriptionEnd?.cancel()
                    self.currentlyMovingChessPieceCollisionSubscriptionEnd = nil
                    self.deactivateInput()
                }
            }
        }
    }
    
    func getDefeatedPieces(side: String) -> [String] {
        var defeatedPieces: [String] = []
        
        game.lastKnownPosition.forEach { piece, field in
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
    
    func moveCube(entity: Entity, to: SIMD3<Float>) {
        entity.setPosition(to, relativeTo: nil)
    }

    func isValidChessField(field: String) -> Bool {
        let validFiles = "abcdefgh"
        let validRanks = "12345678"
        
        guard field.count == 2 else { return false }
        
        let file = field.first!
        let rank = field.last!
        
        return validFiles.contains(file) && validRanks.contains(rank)
    }

    func isValidChessPiece(piece: String) -> Bool {
        return ChessPiece(rawValue: piece) != nil
    }

    func deactivateInput() {
//        guard let color = localPlayer.side?.rawValue else { return }
//        guard let pieces = self.contentEntity.findEntity(named: color)?.children else { return }
//
//        pieces.forEach { piece in
//            if let inputTarget = piece.components[InputTargetComponent.self] {
//                // If the component exists, disable input
//                piece.components[InputTargetComponent.self]?.isEnabled = false
//            }
//        }
    }


    func activateInput() {
//        guard let color = localPlayer.side?.rawValue else { return }
//        guard let pieces = self.contentEntity.findEntity(named: color)?.children else { return }
//
//        pieces.forEach { piece in
//            print(piece) // Debugging log
//
//            if let inputTarget = piece.components[InputTargetComponent.self] {
//                // If InputTargetComponent exists, enable it
//                piece.components[InputTargetComponent.self]?.isEnabled = true
//            } else {
//                // If missing, add InputTargetComponent
//                piece.components.set(InputTargetComponent())
//            }
//        }
    }
    
    func hideAllFieldEntities() {
        let tiles = self.contentEntity.findEntity(named: "tiles_transform")?.children
        tiles?.forEach{ tile in
            tile.components[OpacityComponent.self]?.opacity = 0.0
        }
    }


    func handleCollisions(content: RealityViewContent) {
        if let currentChessPiece = currentlyMovingChessPiece {
            if (currentlyMovingChessPieceCollisionSubscription == nil) {
                let subscription = content.subscribe(to: CollisionEvents.Began.self, on: currentChessPiece) { collisionEvent in
                    print("Collision with \(collisionEvent.entityB.name)")
                    
                    if self.isValidChessField(field: collisionEvent.entityB.name) {
                        self.currentTargetField.append(collisionEvent.entityB)
                        collisionEvent.entityB.components[OpacityComponent.self]?.opacity = 0.4
                        
                    } else if self.isValidChessPiece(piece: collisionEvent.entityB.name) {
                        print("Chess Piece Collision")
                        
                        let targetPieceEntity = collisionEvent.entityB
                        let currentTargetPiece = ChessPiece(rawValue: targetPieceEntity.name)!
                        
                        if (currentChessPiece.name.hasPrefix("white") && targetPieceEntity.name.hasPrefix("black"))
                            || (currentChessPiece.name.hasPrefix("black") && targetPieceEntity.name.hasPrefix("white")) {
                            
                            self.game.lastKnownPosition[currentTargetPiece] = .defeated
                            targetPieceEntity.removeFromParent()
                        }
                    }
                }
                
                let subscriptionEnd = content.subscribe(to: CollisionEvents.Ended.self, on: currentChessPiece) { collisionEvent in
                    if self.isValidChessField(field: collisionEvent.entityB.name) {
                        self.currentTargetField.removeAll(where: {$0.name == collisionEvent.entityB.name})
                        collisionEvent.entityB.components[OpacityComponent.self]?.opacity = 0.0
                    }
                }
                
                DispatchQueue.main.async {
                    self.currentlyMovingChessPieceCollisionSubscription = subscription
                    self.currentlyMovingChessPieceCollisionSubscriptionEnd = subscriptionEnd
                }
            }
        }
    }
}
