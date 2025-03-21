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
import RealityKitContent
import RealityKit

@Observable @MainActor
final class GameController: GameControllerProtocol {
    var opponentStrength: GameModel.OpponentStrength = .medium
    var currentTargetField: [Entity] = []
    var currentlyCapturedPieces: [ChessPiece] = []
    var currentlyMovingChessPiece: Entity? = nil
    var currentlyMovingChessPieceCollisionSubscription: EventSubscription? = nil
    var currentlyMovingChessPieceCollisionSubscriptionEnd: EventSubscription? = nil
    var contentEntity = Entity()
    var deviceLocation: Entity = .init()
    var raycastOrigin: Entity = .init()
    var placementLocation: Entity = .init()
    var fieldEntities: [ChessField: Entity] = [:]
    var pieceEntities: [ChessPiece: Entity] = [:]
    
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
    
    init() {
        contentEntity.addChild(placementLocation)
        deviceLocation.addChild(raycastOrigin)
        
        // Angle raycasts 15 degrees down.
        let raycastDownwardAngle = 15.0 * (Float.pi / 180)
        raycastOrigin.orientation = simd_quatf(angle: -raycastDownwardAngle, axis: [1.0, 0.0, 0.0])
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
        
        Task {
            if game.mode == .mixed {
                await self.startBoardConstruction()
            }
            await self.findAllFieldEntities()
            await self.findAllPieceEntities()
            
            let deviceId = UIDevice.current.identifierForVendor?.uuidString
            if let deviceId = deviceId {
                let request = GameRequest(white: deviceId, black: "", opponent: GameRequest.Opponent.init(rawValue: game.mode!.description.uppercased())!, opponentStrength: opponentStrength.level)
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
    }
    
    func beginTurn() {
        game.stage = .inGame(.duringPlayersTurn)
        
        highlightCheck()
        
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
                    
                    // Get characters at index 2 and 3 (3rd and 4th characters)
                    let startIndex = move.index(move.startIndex, offsetBy: 2)
                    let endIndex = move.index(startIndex, offsetBy: 2)
                    let to = ChessField(rawValue: String(move[startIndex..<endIndex]))
                    
                    let promotedPiece = ChessPieceFen(rawValue: String(move.suffix(1)))
                    
                    if let from = from, let to = to {
                        let pieceToMove = self.getPieceByField(field: from)
                        let chessPieceEntity = self.pieceEntities[pieceToMove!]
                        let chessFieldEntity = self.fieldEntities[to]
                        
                        if let pieceToMove = pieceToMove, let chessPieceEntity = chessPieceEntity, let chessFieldEntity = chessFieldEntity {
                            self.currentlyMovingChessPiece = chessPieceEntity
                            
                            Task {
                                await self.animateMove(piece: chessPieceEntity, field: chessFieldEntity)
                                
                                self.move(piece: pieceToMove, to: to, promotedPiece: promotedPiece) { response in
                                    guard response == true else {
                                        return
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } else {
            self.localPlayer.isPlaying = true
            self.getBestMove { move in
                if let move = move {
                    let move = move.split(separator: ",")[0]
                    guard move != "(none)" else {
                        // Checkmate
                        self.setWinner(side: self.game.currentSide == .white ? .black : .white)
                        return
                    }
                    
                    let from = ChessField(rawValue: String(move.prefix(2)))
                    // Get characters at index 2 and 3 (3rd and 4th characters)
                    let startIndex = move.index(move.startIndex, offsetBy: 2)
                    let endIndex = move.index(startIndex, offsetBy: 2)
                    let to = ChessField(rawValue: String(move[startIndex..<endIndex]))
                    
                    if let from = from, let to = to {
                        let chessFieldFromEntity = self.fieldEntities[from]
                        let chessFieldToEntity = self.fieldEntities[to]
                        
                        if let chessFieldToEntity = chessFieldToEntity, let chessFieldFromEntity = chessFieldFromEntity {
                            chessFieldFromEntity.components[OpacityComponent.self]?.opacity = 0.4
                            chessFieldToEntity.components[OpacityComponent.self]?.opacity = 0.4
                            
                            self.activateInput()
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
        print("End Turn")
        
        currentTargetField = []
        currentlyMovingChessPiece = nil
        currentlyCapturedPieces = []
        currentlyMovingChessPieceCollisionSubscription?.cancel()
        currentlyMovingChessPieceCollisionSubscription = nil
        currentlyMovingChessPieceCollisionSubscriptionEnd?.cancel()
        currentlyMovingChessPieceCollisionSubscriptionEnd = nil
        deactivateInput()
        hideAllFieldEntities()
        
        game.stage = .inGame(.beforePlayersTurn)
        game.currentSide = game.currentSide == .white ? .black : .white
        
        print(game.currentSide)
        
        if game.currentSide != localPlayer.side {
            localPlayer.isPlaying = false
        }
        self.beginTurn()
    }
    
    func setWinner(side: PlayerModel.Side) {
        currentTargetField = []
        currentlyMovingChessPiece = nil
        currentlyCapturedPieces = []
        currentlyMovingChessPieceCollisionSubscription?.cancel()
        currentlyMovingChessPieceCollisionSubscription = nil
        currentlyMovingChessPieceCollisionSubscriptionEnd?.cancel()
        currentlyMovingChessPieceCollisionSubscriptionEnd = nil
        deactivateInput()
        hideAllFieldEntities()
        
        game.winner = side
        game.stage = .gameOver
    }
    
    func endGame() {
        currentTargetField = []
        currentlyMovingChessPiece = nil
        currentlyCapturedPieces = []
        currentlyMovingChessPieceCollisionSubscription?.cancel()
        currentlyMovingChessPieceCollisionSubscription = nil
        currentlyMovingChessPieceCollisionSubscriptionEnd?.cancel()
        currentlyMovingChessPieceCollisionSubscriptionEnd = nil
        deactivateInput()
        hideAllFieldEntities()
        
        game.gameStateFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        game.currentSide = .white
        game.lastKnownPosition = initialPosition
        game.stage = .modeSelection
    }
    
    func gameStateChanged() {
        if game.stage == .modeSelection {
            localPlayer.isPlaying = false
        }
    }
    
    func move(piece: ChessPiece, to: ChessField, promotedPiece: ChessPieceFen?, completion: @escaping (Bool) -> Void) {
        guard let gameId = game.gameId else {
            completion(false)
            return
        }

        guard let from = game.lastKnownPosition[piece], from != to else {
            completion(false)
            return
        }

        var promotedPieceVar = promotedPiece
        if promotedPieceVar == nil, let autoPromoted = getAutoPromotion(for: piece, to: to) {
            promotedPieceVar = autoPromoted
        }

        let moveRequest = MoveRequest(move: "\(from)\(to)\(promotedPieceVar?.rawValue ?? "")")

        GamesAPI.gamesIdMovePost(id: gameId, moveRequest: moveRequest) { response, error in
            guard error == nil else {
                print("Error performing move: \(error!.localizedDescription)")
                completion(false)
                return
            }

            print("Move \(from)\(to) successfully executed")
            
            // Update piece position
            self.game.lastKnownPosition[piece] = to

            // Handle promotion
            if let promoted = promotedPieceVar {
                Task {
                    await self.promotePawn(pawn: piece, to: promoted)
                }
            }

            // Handle castling
            self.handleCastlingIfNeeded(for: piece, from: from, to: to)

            // Handle en passant
            self.handleEnPassantIfNeeded(for: piece, to: to)

            // Remove captured piece if any
            self.removeDefeatedPieces(at: to)

            // Update game state from server
            self.updateGameState(with: response)

            self.endTurn()
            completion(true)
        }
    }
    
    private func getAutoPromotion(for piece: ChessPiece, to field: ChessField) -> ChessPieceFen? {
        if piece.rawValue.hasPrefix("whitePawn") && field.rawValue.hasSuffix("8") {
            return .whiteQueen
        } else if piece.rawValue.hasPrefix("blackPawn") && field.rawValue.hasSuffix("1") {
            return .blackQueen
        }
        return nil
    }

    private func handleCastlingIfNeeded(for piece: ChessPiece, from: ChessField, to: ChessField) {
        guard (piece == .whiteKing || piece == .blackKing),
              let castlingMove = CastlingMove(rawValue: "\(from)\(to)"),
              let info = castlingMap[castlingMove],
              let rookEntity = self.pieceEntities[info.rookPiece],
              let fieldEntity = self.fieldEntities[info.targetField] else { return }

        Task {
            await self.animateMove(piece: rookEntity, field: fieldEntity)
        }
        self.game.lastKnownPosition[info.rookPiece] = info.targetField
    }

    private func handleEnPassantIfNeeded(for piece: ChessPiece, to: ChessField) {
        guard let enPassant = self.isEnPassantPossible(), to.rawValue == enPassant else { return }

        print("En passant target: \(enPassant)")

        let isWhite = piece.rawValue.hasPrefix("whitePawn")
        let isBlack = piece.rawValue.hasPrefix("blackPawn")
        let rank = enPassant.suffix(1)
        let file = enPassant.prefix(1)

        let expectedRank = isWhite ? "6" : isBlack ? "3" : nil
        let captureRank = isWhite ? "5" : isBlack ? "4" : nil

        if let expectedRank = expectedRank, let captureRank = captureRank {
            if rank == expectedRank, let captureSquare = ChessField(rawValue: "\(file)\(captureRank)") {
                if let targetPiece = self.game.lastKnownPosition.first(where: { $0.value == captureSquare })?.key {
                    self.currentlyCapturedPieces.append(targetPiece)
                    self.removeDefeatedPieces(at: captureSquare)
                }
            }
        }
    }

    private func updateGameState(with response: MoveResponse?) {
        self.game.gameStateFen = response?.newGameState.gameState ?? self.game.gameStateFen
        self.game.moveHistory = response?.newGameState.moves ?? self.game.moveHistory
        self.game.checkers = response?.newGameState.checkers.compactMap { ChessField(rawValue: $0) } ?? self.game.checkers
    }
    
    func movePieceToLastKnownPosition(piece: Entity) {
        currentTargetField = []
        currentlyMovingChessPiece = nil
        currentlyCapturedPieces = []
        currentlyMovingChessPieceCollisionSubscription?.cancel()
        currentlyMovingChessPieceCollisionSubscription = nil
        currentlyMovingChessPieceCollisionSubscriptionEnd?.cancel()
        currentlyMovingChessPieceCollisionSubscriptionEnd = nil
        hideAllFieldEntities()
        
        if let initialField = getFieldEntityFromChessPieceEntity(piece) {
            Task {
                await animateMove(piece: piece, field: initialField)
                initialField.components[OpacityComponent.self]?.opacity = 0.4
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    initialField.components[OpacityComponent.self]?.opacity = 0.0
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        initialField.components[OpacityComponent.self]?.opacity = 0.4
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            initialField.components[OpacityComponent.self]?.opacity = 0.0
                        }
                    }
                }
            }
        }
    }

    func removeDefeatedPieces(at: ChessField) {
        for defeatedPiece in self.currentlyCapturedPieces {
            if self.game.lastKnownPosition[defeatedPiece] == at {
                print("Removing piece \(defeatedPiece)")
                self.game.lastKnownPosition[defeatedPiece] = .defeated
                self.pieceEntities[defeatedPiece]?.removeFromParent()
            }
        }
    }
    
    func findAllFieldEntities() async {
        // Wait until the "tiles_transform" entity is available
        await waitForEntities(named: ["tiles_transform"])
        guard let tilesTransform = contentEntity.findEntity(named: "tiles_transform") else { return }
        
        self.fieldEntities = Dictionary(uniqueKeysWithValues: tilesTransform.children.compactMap { entity in
            guard let field = ChessField(rawValue: entity.name) else { return nil }
            print(field)
            return (field, entity)
        })
    }

    func findAllPieceEntities() async {
        // Wait until required entities are available
        await waitForEntities(named: ["black", "white"])
        
        var pieceEntities: [ChessPiece: Entity] = [:]
        
        if let blackPieces = contentEntity.findEntity(named: "black") {
            for entity in blackPieces.children {
                if let piece = ChessPiece(rawValue: entity.name) {print(piece)
                    pieceEntities[piece] = entity
                }
            }
        }
        
        if let whitePieces = contentEntity.findEntity(named: "white") {
            for entity in whitePieces.children {
                if let piece = ChessPiece(rawValue: entity.name) {
                    pieceEntities[piece] = entity
                }
            }
        }
        
        self.pieceEntities = pieceEntities
    }

    func handleCollisions(content: RealityViewContent) {
        if let currentChessPiece = currentlyMovingChessPiece {
            if (currentlyMovingChessPieceCollisionSubscription == nil) {
                let subscription = content.subscribe(to: CollisionEvents.Began.self, on: currentChessPiece) { collisionEvent in
                    print("Collision with \(collisionEvent.entityB.name)")
                    
                    if self.isValidChessField(field: collisionEvent.entityB.name) {
                        self.currentTargetField.append(collisionEvent.entityB)
                        collisionEvent.entityB.components[OpacityComponent.self]?.opacity = 0.4
                        
                    } else if self.isValidChessPiece(piece: currentChessPiece.name == collisionEvent.entityB.name ? collisionEvent.entityA.name : collisionEvent.entityB.name) {
                        print("Chess Piece Collision")
                        
                        let targetPieceEntity = currentChessPiece.name == collisionEvent.entityB.name ? collisionEvent.entityA : collisionEvent.entityB
                        let currentTargetPiece = ChessPiece(rawValue: targetPieceEntity.name)!
                        
                        if (currentChessPiece.name.hasPrefix("white") && targetPieceEntity.name.hasPrefix("black"))
                            || (currentChessPiece.name.hasPrefix("black") && targetPieceEntity.name.hasPrefix("white")) {
                            
                            self.currentlyCapturedPieces.append(currentTargetPiece)
                        }
                        targetPieceEntity.components.remove(PhysicsBodyComponent.self)
                    }
                }
                
                let subscriptionEnd = content.subscribe(to: CollisionEvents.Ended.self, on: currentChessPiece) { collisionEvent in
                    if ChessField(rawValue: collisionEvent.entityB.name) != nil {
                        self.currentTargetField.removeAll(where: {$0.name == collisionEvent.entityB.name})
                        collisionEvent.entityB.components[OpacityComponent.self]?.opacity = 0.0
                        
                        print("Collision with \(collisionEvent.entityB.name) ended.")
                        
                    } else if self.isValidChessPiece(piece: currentChessPiece.name == collisionEvent.entityB.name ? collisionEvent.entityA.name : collisionEvent.entityB.name) {
                        print("Chess Piece Collision ended")
                        
                        let targetPieceEntity = currentChessPiece.name == collisionEvent.entityB.name ? collisionEvent.entityA : collisionEvent.entityB
                        
                        self.currentlyCapturedPieces.removeAll(where: { $0 == ChessPiece(rawValue: targetPieceEntity.name)! })
                        targetPieceEntity.components.set(PhysicsBodyComponent())
                    }
                }
                
                DispatchQueue.main.async {
                    self.currentlyMovingChessPieceCollisionSubscription = subscription
                    self.currentlyMovingChessPieceCollisionSubscriptionEnd = subscriptionEnd
                }
            }
        }
    }
    
    func promotePawn(pawn: ChessPiece, to promotedPiece: ChessPieceFen) async {
        let side: PlayerModel.Side = pawn.rawValue.hasPrefix(PlayerModel.Side.white.rawValue) ? .white : .black
        
        var promotedPieceEntity: Entity?
        
        if let model = chessPieceToModel[promotedPiece.description] {
            promotedPieceEntity = try? await Entity(named: model)
        }

        if let pawnEntity = pieceEntities[pawn], let promotedPieceEntity = promotedPieceEntity {
            if let piecesTransform = contentEntity.findEntity(named: side.rawValue.lowercased()) {
                
                promotedPieceEntity.components = pawnEntity.components
                promotedPieceEntity.setScale(.init(x: 1.4, y: 1.4, z: 1.4), relativeTo: nil)
                promotedPieceEntity.position = pawnEntity.position
                pawnEntity.removeFromParent()
                piecesTransform.addChild(promotedPieceEntity)

                pieceEntities[pawn] = promotedPieceEntity
            }
        }
    }
}
