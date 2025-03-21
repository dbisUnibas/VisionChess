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
    var game: GameModel { get set}
    var localPlayer: PlayerModel { get set}
    var gameSyncStore: GameSyncStore { get set}
    var fieldEntities: [ChessField: Entity] { get set}
    var pieceEntities: [ChessPiece: Entity] { get set}
    
    func enterTeamSelection(gameMode: GameModel.GameMode)
    func joinTeam(_ side: PlayerModel.Side?)
    func startSetup()
    func startGame(opponentStrength: GameModel.OpponentStrength)
    func beginTurn()
    func endTurn()
    func endGame()
    func setWinner(side: PlayerModel.Side)
    func gameStateChanged()
    func move(piece: ChessPiece, to: ChessField, promotedPiece: ChessPieceFen?, completion: @escaping (Bool) -> Void)
    
    func movePieceToLastKnownPosition(piece: Entity)
    func handleCollisions(content: RealityViewContent)
    func setPlaneToProjectOnFound(value: Bool)
    func setPlacementLocationTransform(value: Transform)
    func setCurrentlyMovingChessPiece(entity: Entity)
}

extension GameControllerProtocol {
    
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
    
    func getFieldEntityFromChessPieceEntity(_ chessPieceEntity: Entity) -> Entity? {
        let chessPiece = ChessPiece(rawValue: chessPieceEntity.name)
        
        if let chessPiece = chessPiece, let field = game.lastKnownPosition[chessPiece] {
            return self.fieldEntities[field]
        } else {
            return nil
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

    func moveCube(entity: Entity, to: SIMD3<Float>) {
        entity.setPosition(to, relativeTo: nil)
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
    
    func getPieceByField(field: ChessField) -> ChessPiece? {
        return game.lastKnownPosition.first { $0.value == field }?.key
    }
    
    
}
