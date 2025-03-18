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
                    let to = ChessField(rawValue: String(move.suffix(2)))
                    
                    
                    if let from = from, let to = to {
                        let pieceToMove = self.getPieceByField(field: from)
                        let chessPieceEntity = self.pieceEntities[pieceToMove!]
                        let chessFieldEntity = self.fieldEntities[to]
                        
                        if let pieceToMove = pieceToMove, let chessPieceEntity = chessPieceEntity, let chessFieldEntity = chessFieldEntity {
                            self.currentlyMovingChessPiece = chessPieceEntity
                            
                            Task {
                                await self.animateMove(piece: chessPieceEntity, field: chessFieldEntity)
                                
                                self.move(piece: pieceToMove, to: to) { response in
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
                    let to = ChessField(rawValue: String(move.suffix(2)))
                    
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
        
        // self.setWinner(side: self.game.currentSide)
        
        game.stage = .inGame(.beforePlayersTurn)
        game.currentSide = game.currentSide == .white ? .black : .white
        
        print(game.currentSide)
        
        if game.currentSide != localPlayer.side {
            localPlayer.isPlaying = false
        }
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
            return self.fieldEntities[field]
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
                    
                    self.removeDefeatedPieces(at: to)
                    
                    self.game.gameStateFen = response?.newGameState.gameState ?? self.game.gameStateFen
                    self.game.moveHistory = response?.newGameState.moves ?? self.game.moveHistory
                    self.game.checkers = response?.newGameState.checkers.compactMap { ChessField(rawValue: $0) } ?? self.game.checkers
                    self.endTurn()
                    
                    print("Move \(from)\(to) successfully executed")
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
    
    func animateMove(piece: Entity, field: Entity) async {
        piece.components[PhysicsBodyComponent.self]?.isAffectedByGravity = false

        // Step 1: Move up slightly
        let upTransform = Transform(translation: SIMD3(0, 0.05, 0))
        await piece.moveAsync(to: upTransform, relativeTo: piece, duration: 0.5, timingFunction: .easeIn)
        let finalTranslation = field.transform.translation + SIMD3(0, 0.05, 0)
        
        // Step 2: Move to the target field
        let finalTransform = Transform(scale: piece.transform.scale,
                                       rotation: piece.transform.rotation,
                                       translation: finalTranslation)
        await piece.moveAsync(to: finalTransform, relativeTo: piece.parent!, duration: 1.0, timingFunction: .linear)
                
        // Step 3: Move down slightly for a landing effect
        let downTransform = Transform(translation: SIMD3(0, -0.049, 0))
        await piece.moveAsync(to: downTransform, relativeTo: piece, duration: 0.5, timingFunction: .easeOut)
        
        // Step 4: Restore gravity
        piece.components[PhysicsBodyComponent.self]?.isAffectedByGravity = true
        field.components[OpacityComponent.self]?.opacity = 0.0
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
    
    func movePieceToLastKnownPosition(piece: Entity) {
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
    
    func removeDefeatedPieces(at: ChessField) {
        for defeatedPiece in self.currentlyCapturedPieces {
            if self.game.lastKnownPosition[defeatedPiece] == at {
                print("Removing piece \(defeatedPiece)")
                self.game.lastKnownPosition[defeatedPiece] = .defeated
                self.pieceEntities[defeatedPiece]?.removeFromParent()
            }
        }
    }

    func deactivateInput() {
        guard let color = localPlayer.side?.rawValue else { return }
        let localColorPieces = ChessPiece.allCases.filter { $0.rawValue.contains(color) }

        for piece in localColorPieces {
            if let entity = self.pieceEntities[piece]{
                entity.components.remove(InputTargetComponent.self)
            }
        }
    }

    func activateInput() {
        guard let color = localPlayer.side?.rawValue else { return }
        let localColorPieces = ChessPiece.allCases.filter { $0.rawValue.contains(color) }

        for piece in localColorPieces {
            if let entity = self.pieceEntities[piece]{
                entity.components.set(InputTargetComponent())
            }
        }
    }
    
    func highlightCheck() {
        if !game.checkers.isEmpty {
            game.checkers.forEach { checker in
                let checkerFieldEntity = self.fieldEntities[checker]
                let checkerPiece = self.game.lastKnownPosition.first(where: {$0.value == checker})
                if let checkerPiece = checkerPiece {
                    var kingField: ChessField? = nil
                    
                    if checkerPiece.key.rawValue.contains(PlayerModel.Side.white.rawValue) {
                        kingField = self.game.lastKnownPosition[ChessPiece.blackKing]
                    } else {
                        kingField = self.game.lastKnownPosition[ChessPiece.whiteKing]
                    }
                    
                    if let kingField = kingField {
                        var kingFieldEntity = self.fieldEntities[kingField]
                        if let kingFieldEntity = kingFieldEntity {
                            kingFieldEntity.components[OpacityComponent.self]?.opacity = 1
                        }
                    }
                }
                
                if let checkerFieldEntity = checkerFieldEntity {
                    checkerFieldEntity.components[OpacityComponent.self]?.opacity = 1
                }
            }
        }
    }
    
    func hideAllFieldEntities() {
        for chessField in ChessField.allCases {
            if let entity = self.fieldEntities[chessField] {
                entity.components[OpacityComponent.self]?.opacity = 0.0
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
    
    private func waitForEntities(named entityNames: [String], timeout: TimeInterval = 10.0) async {
        let startTime = Date()
        
        while true {
            // Check if all entities are found
            let foundEntities = entityNames.compactMap { contentEntity.findEntity(named: $0) }
            
            if foundEntities.count == entityNames.count {
                return // All required entities found, exit the loop
            }

            // Timeout handling to prevent infinite loop
            if Date().timeIntervalSince(startTime) > timeout {
                print("Timeout waiting for entities: \(entityNames)")
                return
            }

            // Wait for a short period before checking again
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
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
    
    func startBoardConstruction() async {
        print("Construction started...")
        await waitForEntities(named: ["Pointer1", "Pointer2"])
        
        guard let pointer1Entity = contentEntity.findEntity(named: "Pointer1"),
              let pointer2Entity = contentEntity.findEntity(named: "Pointer2") else {
            print("Pointers not found")
            return
        }
        
        // Get world positions of the pointers
        let position1 = pointer1Entity.position(relativeTo: nil)
        let position2 = pointer2Entity.position(relativeTo: nil)
        
        // Compute the direction vector (Pointer1 -> Pointer2)
        let direction = normalize(position2 - position1)
        
        // Compute the midpoint
        let midpoint = SIMD3<Float>(
            (position1.x + position2.x) / 2,
            position1.y, // Same Y-axis value
            (position1.z + position2.z) / 2
        )
        
        print(midpoint)
        
        // Compute the distance in the XZ plane
        let dx = position2.x - position1.x
        let dz = position2.z - position1.z
        let distance = sqrt(dx * dx + dz * dz)  // Euclidean distance in XZ plane
        
        print(distance)
        
        // Chessboard original size
        let originalSize: Float = 0.45255 // 32cmx32cm diagonally
        
        // Compute the scale factor to fit the distance
        let scaleFactor = distance / originalSize
        
        print(scaleFactor)
        
        // Load chessboard model (assuming it exists in assets)
        guard let chessboardModel = try? await Entity(named: "Board-Mixed", in: realityKitContentBundle) else {
            print("Chessboard model not found")
            return
        }
        
        // Apply scaling
        chessboardModel.setScale(SIMD3<Float>(scaleFactor, scaleFactor, scaleFactor), relativeTo: chessboardModel) // Scale only in X and Z
        
        // Define the default right vector (chessboard's local X-axis)
        let defaultRightVector = SIMD3<Float>(1, 0, 0) // Default X-axis in model space

        // Compute rotation to align chessboard's X-axis with the direction vector
        let rotationQuaternion = simd_quatf(from: defaultRightVector, to: SIMD3<Float>(direction.x, 0, direction.z))

        // Apply rotation to align the board
        chessboardModel.orientation = rotationQuaternion
        
        // Set position at midpoint
        chessboardModel.position = midpoint
        
        // Add to scene
        contentEntity.addChild(chessboardModel)
        
        let transform = chessboardModel.findEntity(named: localPlayer.side?.rawValue ?? "")
        transform?.children.forEach {piece in
            piece.components.set(HoverEffectComponent())
        }
    }
}
