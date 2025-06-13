//
//  RevieweController.swift
//  VisionChess
//
//  Created by Tim Bachmann on 11.04.2025.
//

import Observation
import Foundation
import SwiftUI
import OpenAPIClient
import RealityKitContent
import RealityKit
import AVFoundation

@Observable @MainActor
final class ReviewController: GameControllerProtocol {
    var opponentStrength: GameModel.OpponentStrength = .medium
    var suggestionLevel: GameModel.SuggestionLevel = .medium
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
    var rawPrediction: ChessPieceDetectionManager.ChessBoardPredictionResult?
    var currentMoveEstimate: String?
    var moveRequestPending: Bool = false
    var alert: String? = nil
    
    var currentMoveIndex: Int = 0
    
    
    private var sfxPlayer: AVAudioPlayer?
    
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
    
    var localPlayer = PlayerModel(id: UUID(), name: "You", deviceId: UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString)
    
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
    }
    
    func enterRecentGames() {
        game.stage = .recentGames
    }
    
    func joinTeam(_ side: PlayerModel.Side?) {
        localPlayer.side = side
    }
    
    func setGameID(_ id: String) {
        self.game.gameId = id
    }
    
    func setMoveHistory(_ history: [String]) {
        self.game.moveHistory = history
    }
    
    func startSetup() {
        game.stage = .inSetup
    }
    
    func startGame() {
        game.stage = .inGame(.beforePlayersTurn)
        
        Task {
            await self.findAllFieldEntities()
            await self.findAllPieceEntities()
            self.playSoundEffect(SFX.boom)
        }
    }
    
    func nextMove() {
        if game.moveHistory.count <= currentMoveIndex {
            return
        }
        game.stage = .inGame(.duringPlayersTurn)
        
        let move = game.moveHistory[currentMoveIndex]
        let from = ChessField(rawValue: String(move.prefix(2)))
        
        // Get characters at index 2 and 3 (3rd and 4th characters)
        let startIndex = move.index(move.startIndex, offsetBy: 2)
        let endIndex = move.index(startIndex, offsetBy: 2)
        let to = ChessField(rawValue: String(move[startIndex..<endIndex]))
        
        let promotedPiece = ChessPieceFen.fromLowerCased(moveNotation: String(move.suffix(1)), side: self.localPlayer.side == .black ? .white : .black)
        
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
                        
                        self.currentMoveIndex += 1
                        if self.game.moveHistory.count <= self.currentMoveIndex {
                            self.setWinner(side: self.game.currentSide == .white ? .black : .white)
                        }
                    }
                }
            }
        }
    }
    
    func previousMove() {
        if currentMoveIndex < 0 {
            return
        }
        let move = game.moveHistory[currentMoveIndex-1]
        let to = ChessField(rawValue: String(move.prefix(2)))
        
        game.stage = .inGame(.duringPlayersTurn)
        
        // Get characters at index 2 and 3 (3rd and 4th characters)
        let startIndex = move.index(move.startIndex, offsetBy: 2)
        let endIndex = move.index(startIndex, offsetBy: 2)
        let from = ChessField(rawValue: String(move[startIndex..<endIndex]))
        
        let promotedPiece = ChessPieceFen.fromLowerCased(moveNotation: String(move.suffix(1)), side: self.localPlayer.side == .black ? .white : .black)
        
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
                        
                        self.currentMoveIndex -= 1
                    }
                }
            }
        }
    }
    
    func beginTurn() {}
    
    func endTurn() {
        guard game.stage.isInGame else {
            return
        }
        
        currentTargetField = []
        currentlyMovingChessPiece = nil
        currentlyCapturedPieces = []
        currentlyMovingChessPieceCollisionSubscription?.cancel()
        currentlyMovingChessPieceCollisionSubscription = nil
        currentlyMovingChessPieceCollisionSubscriptionEnd?.cancel()
        currentlyMovingChessPieceCollisionSubscriptionEnd = nil
        deactivateInput()
        hideAllFieldEntities()
        self.currentMoveEstimate = nil
        
        game.stage = .inGame(.beforePlayersTurn)
        game.currentSide = game.currentSide == .white ? .black : .white
        
        if game.currentSide != localPlayer.side {
            localPlayer.isPlaying = false
        }
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
        game.stage = game.mode == .review ? .recentGames : .modeSelection
    }
    
    func gameStateChanged() {
        if game.stage == .modeSelection {
            localPlayer.isPlaying = false
        }
    }
    
    func move(piece: ChessPiece, to: ChessField, promotedPiece: ChessPieceFen?, completion: @escaping (Bool) -> Void) {
        guard game.gameId != nil else {
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
        self.removeDefeatedPieces(updatedPiece: piece, at: to)

        self.endTurn()
        completion(true)
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
              let info = castlingMap[castlingMove] else { return }
              
        if let side = self.localPlayer.side?.rawValue,
              let rookEntity = self.pieceEntities[info.rookPiece],
              let fieldEntity = self.fieldEntities[info.targetField],
              self.game.mode != .mixed || self.game.mode == .mixed && !piece.rawValue.hasPrefix(side) {
            Task {
                await self.animateMove(piece: rookEntity, field: fieldEntity)
            }
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
                    self.removeDefeatedPieces(updatedPiece: piece, at: captureSquare)
                }
            }
        }
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
    
    func resetAlert() {
        self.alert = nil
    }

    func removeDefeatedPieces(updatedPiece: ChessPiece, at: ChessField) {
        if self.currentlyCapturedPieces.isEmpty {
            if let defeatedPiece = self.game.lastKnownPosition.filter({$0.key != updatedPiece}).first(where: { $0.value == at })?.key {
                print("Removing piece \(defeatedPiece)")
                self.playSoundEffect(SFX.capture)
                self.game.lastKnownPosition[defeatedPiece] = .defeated
                self.pieceEntities[defeatedPiece]?.removeFromParent()
                
                if let side = localPlayer.side?.rawValue, defeatedPiece.rawValue.contains(side) {
                    self.alert = "Please remove your piece at \(at)!"
                }
            }
        } else {
            for defeatedPiece in self.currentlyCapturedPieces {
                if self.game.lastKnownPosition[defeatedPiece] == at {
                    print("Removing piece \(defeatedPiece)")
                    
                    self.playSoundEffect(SFX.capture)
                    self.game.lastKnownPosition[defeatedPiece] = .defeated
                    self.pieceEntities[defeatedPiece]?.removeFromParent()
                }
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
        var availableSides: [String] = []
        if game.mode == .mixed {
            availableSides.append(localPlayer.side?.rawValue == "white" ? "black" : "white")
        } else {
            availableSides.append(contentsOf: ["black", "white"])
        }
        
        await waitForEntities(named: availableSides)
        
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
                    } else if collisionEvent.entityB.name == "mesh" || collisionEvent.entityB.name.hasPrefix("Plane") {
                        self.playSoundEffect(SFX.moveSelf)
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
                promotedPieceEntity.setScale(.init(x: 1.7, y: 1.7, z: 1.7), relativeTo: nil)
                promotedPieceEntity.position = pawnEntity.position
                pawnEntity.removeFromParent()
                piecesTransform.addChild(promotedPieceEntity)

                pieceEntities[pawn] = promotedPieceEntity
            }
        }
    }
    
    func playSoundEffect(_ name: SFX) {
        guard let url = Bundle.main.url(forResource: name.rawValue, withExtension: "mp3") else {
            print("❌ SFX file not found: \(name)")
            return
        }

        do {
            sfxPlayer = try AVAudioPlayer(contentsOf: url)
            sfxPlayer?.volume = 1.5
            sfxPlayer?.play()
        } catch {
            print("❌ Error playing sound effect: \(error)")
        }
    }
    
    func setSuggestionLevel(_ level: GameModel.SuggestionLevel) {
        self.suggestionLevel = level
    }
    
    func update(prediction: ChessPieceDetectionManager.ChessBoardPredictionResult) async {}
    
    func applyPhysicalMove() {}

}
