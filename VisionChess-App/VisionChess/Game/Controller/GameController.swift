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
import AVFoundation
import Vision

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
    var prediction: ChessPieceDetectionManager.ChessBoardPredictionResult?
    var image: Image?
    var fen: [[String]] = []
    
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
                    self.playSoundEffect(SFX.boom)
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
                    
                    self.activateInput()
                    
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
                            
                            self.playSoundEffect(SFX.notify)
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
                
                self.playSoundEffect(SFX.capture)
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
                promotedPieceEntity.setScale(.init(x: 1.4, y: 1.4, z: 1.4), relativeTo: nil)
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
    
    func orderPoints(pts: [CGPoint]) -> [CGPoint] {
        let sums = pts.map { $0.x + $0.y }
        let diffs = pts.map { $0.y - $0.x }
        
        var rect = [CGPoint](repeating: CGPoint.zero, count: 4)
        
        if let topLeftIndex = sums.enumerated().min(by: { $0.element < $1.element })?.offset {
            rect[0] = pts[topLeftIndex]
        }
        if let bottomRightIndex = sums.enumerated().max(by: { $0.element < $1.element })?.offset {
            rect[2] = pts[bottomRightIndex]
        }
        if let topRightIndex = diffs.enumerated().min(by: { $0.element < $1.element })?.offset {
            rect[1] = pts[topRightIndex]
        }
        if let bottomLeftIndex = diffs.enumerated().max(by: { $0.element < $1.element })?.offset {
            rect[3] = pts[bottomLeftIndex]
        }
        
        return rect
    }

    
    func getCornerPoints(_ boundingBox: CGRect, masks: MLMultiArray, bestMaskIdx: Int) -> [CGPoint] {
        let imageViewWidth = CGFloat(640)
        let imageViewHeight = CGFloat(640)
        let scaledX : CGFloat = (boundingBox.minX/640)*imageViewWidth
        let scaledY : CGFloat = (boundingBox.minY/640)*imageViewHeight
        let scaledWidth : CGFloat = (boundingBox.width/640)*imageViewWidth
        let scaledHeight : CGFloat = (boundingBox.height/640)*imageViewHeight
        
        let rectangle = CGRect(x: scaledX, y: scaledY, width: scaledWidth, height: scaledHeight)
        
        let maskProbThreshold : Float = 0.4
        var maskProbalities : [[Float]] = [] //this will contains 160x160 mask pixel probablities
        var maskProbYAxis : [Float] = []
        
        let mask_x_min = (rectangle.minX/imageViewWidth)*160
        let mask_x_max = (rectangle.maxX/imageViewWidth)*160
        
        let mask_y_min = (rectangle.minY/imageViewHeight)*160
        let mask_y_max = (rectangle.maxY/imageViewHeight)*160
        
        for y in 0..<masks.shape[2].intValue{
            maskProbYAxis.removeAll()
            for x in 0..<masks.shape[3].intValue{
                let pointKey = [0, bestMaskIdx, y, x] as [NSNumber]
                if(sigmoid(z: masks[pointKey].floatValue) > maskProbThreshold
                   && x >=  Int(mask_x_min) && x <= Int(mask_x_max)
                && y >= Int(mask_y_min) && y <= Int(mask_y_max)){
                    maskProbYAxis.append(1.0)
                } else {
                    maskProbYAxis.append(0.0)
                }
            }
            maskProbalities.append(maskProbYAxis)
        }
        
        var finalPoints: [CGPoint] = []
        for y in 0..<maskProbalities.count {
            for x in 0..<maskProbalities[y].count{
                
                let xFactor = Float(imageViewWidth)/160
                let yFactor = Float(imageViewHeight)/160
                let maskScaled_X = Double(x) * Double(xFactor)
                let maskScaled_Y = Double(y) * Double(yFactor)
                
                if(maskProbalities[y][x] == 1.0) {
                    finalPoints.append(CGPoint(x: maskScaled_X, y: maskScaled_Y))
                }
            }
        }
        
        return orderPoints(pts: finalPoints)
    }
    
    private func sigmoid(z:Float) -> Float{
        return 1.0/(1.0+exp(z))
    }
    
    func getBoundingBox(feature: MLMultiArray) -> (CGRect, Int) {
        var boundingBox = CGRect(x: 0,y: 0,width: 10,height: 10)
        
        var bestMaskIdx = 0
        var probMaxIdx = 0
        var maxProb : Float = 0
        var box_x : Float = 0
        var box_y : Float = 0
        var box_width : Float = 0
        var box_height : Float = 0
        
        for j in 0..<feature.shape[2].intValue-1
        {
            let key = [0,4,j] as [NSNumber]
            let nextKey = [0,4,j+1] as [NSNumber]
            if(feature[key].floatValue < feature[nextKey].floatValue){
                if(maxProb < feature[nextKey].floatValue){
                    probMaxIdx = j+1
                    let xKey = [0,0,probMaxIdx] as [NSNumber]
                    let yKey = [0,1,probMaxIdx] as [NSNumber]
                    let widthKey = [0,2,probMaxIdx] as [NSNumber]
                    let heightKey = [0,3,probMaxIdx] as [NSNumber]
                    maxProb = feature[nextKey].floatValue
                    box_width = feature[widthKey].floatValue
                    box_height = feature[heightKey].floatValue
                    
                    box_x = feature[xKey].floatValue - (box_width/2)
                    box_y = feature[yKey].floatValue - (box_height/2)
                }
            }
        }
        boundingBox = CGRect(x: CGFloat(box_x)
                             ,y: CGFloat(box_y)
                             ,width: CGFloat(box_width)
                             ,height: CGFloat(box_height))
        var maxMaskProb : Float = 0
        var maxMaskIdx = 0
        for maskPrbIdx in 5..<feature.shape[1].intValue-1{
            let key = [0,maskPrbIdx,probMaxIdx] as [NSNumber]
            let nextKey = [0,maskPrbIdx+1,probMaxIdx] as [NSNumber]
            if(feature[key].floatValue < feature[nextKey].floatValue){
                if(maxMaskProb < feature[nextKey].floatValue){
                    maxMaskIdx = maskPrbIdx+1
                    maxMaskProb = feature[nextKey].floatValue
                }
            }
            bestMaskIdx = maxMaskIdx-5
        }
        return (boundingBox, bestMaskIdx)
    }
    
    func update(prediction: ChessPieceDetectionManager.ChessBoardPredictionResult) {
        let (boundingBox, bestMaskIdx) = getBoundingBox(feature: prediction.var_1647.featureValue.multiArrayValue!)
        
        let cornerPoints = getCornerPoints(boundingBox, masks: prediction.p.featureValue.multiArrayValue!, bestMaskIdx: bestMaskIdx)
        
        let boardCorners = cornerPoints.map { point -> CGPoint in
                return CGPoint(x: point.x / 640, y: point.y / 640)
            }
        
        //let piecePoints = prediction.pieces.compactMap({CGPoint(x: $0.boundingBox.midX, y: (1.0 - $0.boundingBox.midY) + $0.boundingBox.height/4.0 )})
        
        //image = Image(uiImage: drawPointsOnImage(named: "test", normalizedPoints: boardCorners + piecePoints)!)
        
        //print(boardCorners)
        //print(prediction.pieces)

        // Destination points for a flat 8x8 board
        let destination: [CGPoint] = [
            CGPoint(x: 0, y: 0),   // top-left
            CGPoint(x: 1, y: 0),   // top-right
            CGPoint(x: 1, y: 1),   // bottom-right
            CGPoint(x: 0, y: 1)    // bottom-left
        ]

        // Final board representation: 8 rows of 8 columns (row-major, top to bottom)
        var board = Array(repeating: Array(repeating: nil as String?, count: 8), count: 8)
        
        
        print("Looping over pieces...")
        if let perspectiveTransform = PerspectiveTransform(source: boardCorners, destination: destination) {
            // Example: Map a point from the source space.
            
            for piece in prediction.pieces {
                let centerPoint = center(of: piece.boundingBox)
                
                // Warp to board space (0...1)
                let warped = perspectiveTransform.transform(point: centerPoint)
                
                // Exclude warped points outside the destination square [0, 1] x [0, 1]
                guard warped.x >= 0, warped.x <= 1, warped.y >= 0, warped.y <= 1 else {
                    continue
                }

                // Convert to board coordinates
                let boardX = min(max(Int(warped.x * 8), 0), 7)
                let boardY = min(max(Int(warped.y * 8), 0), 7)

                // print("Piece: \(piece.label.rawValue), BoardX: \(boardX), BoardY: \(boardY), Center: \(centerPoint), Warped: \(warped)")
                // Store label
                if board[boardY][boardX] == nil {
                    board[boardY][boardX] = piece.label.rawValue
                }
            }
        } else {
            print("Failed to compute perspective transform.")
        }

        // Convert to display (reversed if you want rank 8 on top)
        fen = board.map { row in
            row.map { $0 ?? "-" }
        }
        
        // Print board
        for row in board {
            print(row.map { $0 ?? "--" }.joined(separator: " "))
        }

    }

    func drawPointsOnImage(named imageName: String, normalizedPoints: [CGPoint]) -> UIImage? {
        guard let image = UIImage(named: imageName),
              let cgImage = image.cgImage else {
            print("Image not found")
            return nil
        }

        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)

        // Begin drawing context
        UIGraphicsBeginImageContextWithOptions(imageSize, false, 0)
        image.draw(in: CGRect(origin: .zero, size: imageSize))

        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return nil
        }

        context.setFillColor(UIColor.red.cgColor)

        // Draw circles at each normalized point
        for point in normalizedPoints {
            let pixelPoint = CGPoint(x: point.x * imageSize.width, y: point.y * imageSize.height)
            let dotSize: CGFloat = 8.0
            let dotRect = CGRect(x: pixelPoint.x - dotSize / 2, y: pixelPoint.y - dotSize / 2, width: dotSize, height: dotSize)
            context.fillEllipse(in: dotRect)
        }

        let resultImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resultImage
    }
}
