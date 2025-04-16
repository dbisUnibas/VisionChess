//
//  GameControllerProtocol.swift
//  VisionChess
//
//  Created by Tim Bachmann on 12.03.2025.
//

import RealityKit
import SwiftUI
import OpenAPIClient
import RealityKitContent

@MainActor
protocol GameControllerProtocol {
    var suggestionLevel: GameModel.SuggestionLevel { get set }
    var opponentStrength: GameModel.OpponentStrength { get set }
    var currentTargetField: [Entity] { get set }
    var currentlyMovingChessPiece: Entity? { get set }
    var currentlyMovingChessPieceCollisionSubscription: EventSubscription? { get set }
    var currentlyMovingChessPieceCollisionSubscriptionEnd: EventSubscription? { get set }
    var contentEntity: Entity { get set }
    var deviceLocation: Entity { get set }
    var raycastOrigin: Entity { get set }
    var placementLocation: Entity { get set }
    var planeToProjectOnFound: Bool { get set }
    var game: GameModel { get set }
    var localPlayer: PlayerModel { get set }
    var gameSyncStore: GameSyncStore { get set }
    var fieldEntities: [ChessField: Entity] { get set }
    var pieceEntities: [ChessPiece: Entity] { get set }
    var alert: String? { get set }
    var rawPrediction: ChessPieceDetectionManager.ChessBoardPredictionResult? { get set}
    var currentMoveEstimate: String? { get set }
    var moveRequestPending: Bool { get set }
    
    func enterRecentGames()
    func enterTeamSelection(gameMode: GameModel.GameMode)
    func joinTeam(_ side: PlayerModel.Side?)
    func startSetup()
    func startGame()
    func beginTurn()
    func endTurn()
    func endGame()
    func setWinner(side: PlayerModel.Side)
    func gameStateChanged()
    func move(piece: ChessPiece, to: ChessField, promotedPiece: ChessPieceFen?, completion: @escaping (Bool) -> Void)
    func resetAlert()
    func movePieceToLastKnownPosition(piece: Entity)
    func handleCollisions(content: RealityViewContent)
    func setPlaneToProjectOnFound(value: Bool)
    func setPlacementLocationTransform(value: Transform)
    func setCurrentlyMovingChessPiece(entity: Entity)
    func playSoundEffect(_ name: SFX)
    func setSuggestionLevel(_ level: GameModel.SuggestionLevel)
    func setGameID(_ id: String)
    func setMoveHistory(_ history: [String])
    func update(prediction: ChessPieceDetectionManager.ChessBoardPredictionResult) async
    func applyPhysicalMove()
}

extension GameControllerProtocol {
    
    func getBestMove(opponentStrength: GameModel.OpponentStrength? = nil, completion: @escaping (String?) -> Void) {
        guard let gameId = game.gameId else {
            completion(nil)
            return
        }
        
        let suggestion = self.suggestionLevel == .off ? GameModel.SuggestionLevel.expert.level : self.suggestionLevel.level
        let level = String(opponentStrength?.level ?? suggestion)
        GamesAPI.gamesIdBestMoveSuggestionLevelGet(id: gameId, suggestionLevel: level) { response, error in
            guard error == nil else {
                print("Error fetching best move: \(error!.localizedDescription)")
                completion(nil)
                return
            }
            print(response ?? "")
            completion(response)
        }
    }
    
    func getFieldEntityFromChessPieceEntity(_ chessPieceEntity: Entity) -> Entity? {
        let chessPiece = ChessPiece(rawValue: chessPieceEntity.name)
        
        if let chessPiece = chessPiece, let field = game.lastKnownPosition[chessPiece] {
            return self.fieldEntities[field]
        } else {
            return nil
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
        
        let chessboardModelString = game.mode == .virtual ? "Board-Mixed" : (localPlayer.side == .white) ? "Board-Mixed-White" : "Board-Mixed-Black"
        
        // Load chessboard model (assuming it exists in assets)
        guard let chessboardModel = try? await Entity(named: chessboardModelString, in: realityKitContentBundle) else {
            print("Chessboard model not found")
            return
        }
        
        // Apply scaling
        chessboardModel.setScale(SIMD3<Float>(scaleFactor, scaleFactor, scaleFactor), relativeTo: chessboardModel) // Scale only in X and Z
        
        // Define the default right vector (chessboard's local X-axis)
        let defaultRightVector = SIMD3<Float>(1, 0, 0) // Default X-axis in model space

        // Compute rotation to align chessboard's X-axis with the direction vector
        let rotationQuaternion = simd_quatf(from: defaultRightVector, to: SIMD3<Float>(direction.x, 0, direction.z))
        let rotation180 = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))

        // Apply rotation to align the board
        if localPlayer.side == .white {
            chessboardModel.orientation = rotationQuaternion
        } else {
            chessboardModel.orientation = rotation180 * rotationQuaternion
        }
        
        
        // Set position at midpoint
        chessboardModel.position = midpoint
        
        // Add to scene
        contentEntity.addChild(chessboardModel)
        
        let transform = chessboardModel.findEntity(named: localPlayer.side?.rawValue ?? "")
        transform?.children.forEach {piece in
            piece.components.set(HoverEffectComponent())
        }
        
        pointer1Entity.findEntity(named: "Root")?.components[OpacityComponent.self]?.opacity = 0
        pointer2Entity.findEntity(named: "Root")?.components[OpacityComponent.self]?.opacity = 0
    }
    
    func waitForEntities(named entityNames: [String], timeout: TimeInterval = 10.0) async {
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
    
    func hideAllFieldEntities() {
        for chessField in ChessField.allCases {
            if let entity = self.fieldEntities[chessField] {
                entity.components[OpacityComponent.self]?.opacity = 0.0
            }
        }
    }
    
    func highlightCheck() {
        if !game.checkers.isEmpty {
            self.playSoundEffect(SFX.check)
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
                        let kingFieldEntity = self.fieldEntities[kingField]
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
    
    func deactivateInput() {
        guard let color = localPlayer.side?.rawValue else { return }
        let localColorPieces = ChessPiece.allCases.filter { $0.rawValue.contains(color) }

        print("Deactivate input")
        for piece in localColorPieces {
            if let entity = self.pieceEntities[piece]{
                entity.components.remove(InputTargetComponent.self)
            }
        }
    }

    func activateInput() {
        guard let color = localPlayer.side?.rawValue else { return }
        let localColorPieces = ChessPiece.allCases.filter { $0.rawValue.contains(color) }

        print("Activate input")
        for piece in localColorPieces {
            if let entity = self.pieceEntities[piece]{
                entity.components.set(InputTargetComponent())
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

    func getDefeatedPieces(side: String) -> [String] {
        var defeatedPieces: [String] = []
        
        game.lastKnownPosition.forEach { piece, field in
            if field == ChessField.defeated && piece.rawValue.hasPrefix(side) {
                if piece == ChessPiece.whiteQueen || piece == ChessPiece.blackQueen {
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
    
    func animateMove(piece: Entity, field: Entity) async {
        piece.components[PhysicsBodyComponent.self]?.isAffectedByGravity = false

        // Step 1: Move up slightly
        let upTransform = Transform(translation: SIMD3(0, 0.05, 0))
        await piece.moveAsync(to: upTransform, relativeTo: piece, duration: 0.3, timingFunction: .easeIn)
        let finalTranslation = field.transform.translation + SIMD3(0, 0.05, 0)
        
        // Step 2: Move to the target field
        let finalTransform = Transform(scale: piece.transform.scale,
                                       rotation: piece.transform.rotation,
                                       translation: finalTranslation)
        await piece.moveAsync(to: finalTransform, relativeTo: piece.parent!, duration: 0.8, timingFunction: .linear)
                
        // Step 3: Move down slightly for a landing effect
        let downTransform = Transform(translation: SIMD3(0, -0.025, 0))
        await piece.moveAsync(to: downTransform, relativeTo: piece, duration: 0.3, timingFunction: .easeOut)
        
        // Step 4: Restore gravity
        piece.components[PhysicsBodyComponent.self]?.isAffectedByGravity = true
        field.components[OpacityComponent.self]?.opacity = 0.0
    }
    
    func getPieceByField(field: ChessField) -> ChessPiece? {
        return game.lastKnownPosition.first { $0.value == field }?.key
    }
    
    func isEnPassantPossible() -> String? {
        let components = game.gameStateFen.split(separator: " ")
        guard components.count >= 4 else {
            return nil
        }

        let enPassantField = String(components[3])
        return enPassantField != "-" ? enPassantField : nil
    }

    func detectPhysicalMove(
        lastKnownPosition: [ChessPiece: ChessField],
        positionEstimate: [ChessField: ChessPieceDetectionManager.PredictionResult.Label]
    ) async -> String? {
        // Determine the local player's side (e.g., "white" or "black").
        let side = localPlayer.side?.rawValue.lowercased() ?? "white"
        
        // Filter the last known state to include only pieces on the local player's side.
        let filteredPositions = lastKnownPosition.filter { (piece, field) in
            return piece.rawValue.lowercased().contains(side) && field != .defeated
        }
        
        // Invert the mapping: from ChessPiece -> ChessField to ChessField -> ChessPiece.
        var piecePositions: [ChessField: ChessPiece] = [:]
        for (piece, field) in filteredPositions {
            piecePositions[field] = piece
        }
        
        var missingSquares: [ChessField] = []
        var newSquares: [ChessField] = []
        
        // Determine which squares are now empty (i.e. missing) and which squares are newly occupied.
        // Detect the source square:
        // The source square is a square that previously held a white piece but now is missing in the vision estimate.
        for (field, _) in piecePositions {
            if positionEstimate[field] == nil {
                missingSquares.append(field)
            }
        }
        
        // Detect the destination square:
        // The destination square is one that now shows a white piece (with the correct generic label)
        // and was not previously occupied by any white piece.
        for (field, _) in positionEstimate {
            if piecePositions[field] == nil {
                newSquares.append(field)
            }
        }
        
        print(missingSquares)
        print(newSquares)
        
        // --- Normal Move Detection ---
        if missingSquares.count == 1 && newSquares.count == 1 {
            let sourceSquare = missingSquares.first!
            let destinationSquare = newSquares.first!
            
//            if let movedPiece = piecePositions[sourceSquare],
//               let expectedLabel = label(for: movedPiece),
//               positionEstimate[destinationSquare] == expectedLabel {
//                return sourceSquare.rawValue + destinationSquare.rawValue
//            }
            return sourceSquare.rawValue + destinationSquare.rawValue
        }
        
        // --- Castling Move Detection ---
        // When castling, both the king and one rook move, so we expect two missing and two new squares.
        else if missingSquares.count == 2 && newSquares.count == 2 {
            var kingSource: ChessField?
            var rookSource: ChessField?
            
            // Identify which missing squares belonged to the king and the rook.
            for square in missingSquares {
                if let piece = piecePositions[square] {
                    // Use the enum's rawValue to determine the piece type.
                    if piece.rawValue.lowercased().contains("king") {
                        kingSource = square
                    } else if piece.rawValue.lowercased().contains("rook") {
                        rookSource = square
                    }
                }
            }
            
            var kingDestination: ChessField?
            var rookDestination: ChessField?
            
            // From the new squares, detect which now show a king or a rook.
            for square in newSquares {
                if let detectedLabel = positionEstimate[square] {
                    // Compare with the expected labels for king and rook.
                    if detectedLabel == label(for: .whiteKing) || detectedLabel == label(for: .blackKing) {
                        kingDestination = square
                    } else if detectedLabel == label(for: .whiteRookA) ||
                              detectedLabel == label(for: .whiteRookH) ||
                              detectedLabel == label(for: .blackRookA) ||
                              detectedLabel == label(for: .blackRookH) {
                        rookDestination = square
                    }
                }
            }
            
            // If we have detected both king and rook moves, verify that the king moved two files.
            if let kingSource = kingSource,
               let kingDestination = kingDestination,
               let _ = rookSource,
               let _ = rookDestination {
                // Assuming the ChessField raw values are like "e1", "g1", etc.
                if let kingSourceFile = kingSource.rawValue.first,
                   let kingDestFile = kingDestination.rawValue.first,
                   abs(Int(kingDestFile.asciiValue!) - Int(kingSourceFile.asciiValue!)) == 2 {
                    // Optionally: further checks can be added to verify that the rook has moved to its expected square.
                    // For now, we simply return the king's move notation (e.g., "e1g1" for kingside castling).
                    return kingSource.rawValue + kingDestination.rawValue
                }
            }
            return nil
        }
        return nil
    }
}
