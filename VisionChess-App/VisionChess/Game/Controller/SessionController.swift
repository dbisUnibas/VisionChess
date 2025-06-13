//
//  SessionController.swift
//  VisionChess
//
//  Created by Tim Bachmann on 12.03.2025.
//

import GroupActivities
import Observation
import RealityKit
import SwiftUI
import RealityKitContent
import OpenAPIClient
import AVFoundation

@Observable @MainActor
final class SessionController: GameControllerProtocol {
    let session: GroupSession<ChessGroupActivity>
    let messenger: GroupSessionMessenger
    let systemCoordinator: SystemCoordinator

    var suggestionLevel: GameModel.SuggestionLevel = .medium
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
    var lastAppliedPosition: [ChessPiece: ChessField] = initialPosition
    var rawPrediction: ChessPieceDetectionManager.ChessBoardPredictionResult?
    var currentMoveEstimate: String?
    var moveRequestPending: Bool = false
    var alert: String? = nil
    
    private var sfxPlayer: AVAudioPlayer?
    
    var currentPlayer: PlayerModel? {
        players.values.first(where: \.isPlaying)
    }
    
    var activeTeam: PlayerModel.Side? {
        return currentPlayer?.side
    }
    
    var game: GameModel {
        get {
            gameSyncStore.game
        }
        set {
            if newValue != gameSyncStore.game {
                gameSyncStore.game = newValue
                shareLocalGameState(newValue)
            }
        }
    }
    
    var gameSyncStore = GameSyncStore() {
        didSet {
            gameStateChanged()
        }
    }

    var players = [Participant: PlayerModel]() {
        didSet {
            if oldValue != players {
                updateCurrentPlayer()
                updateLocalParticipantRole()
            }
        }
    }
    
    var localPlayer: PlayerModel {
        get {
            players[session.localParticipant]!
        }
        set {
            if newValue != players[session.localParticipant] {
                players[session.localParticipant] = newValue
                shareLocalPlayerState(newValue)
            }
        }
    }
    
    var planeToProjectOnFound = false {
        didSet {
            if planeToProjectOnFound {
                contentEntity.addChild(placementLocation)
            } else {
                placementLocation.removeFromParent()
            }
        }
    }
    
    init?(_ groupSession: GroupSession<ChessGroupActivity>, appModel: AppModel) async {
        guard let groupSystemCoordinator = await groupSession.systemCoordinator else {
            return nil
        }

        session = groupSession

        // Create the group session messenger for the session controller, which it uses to keep the game in sync for all participants.
        messenger = GroupSessionMessenger(session: session)

        systemCoordinator = groupSystemCoordinator

        // Create a representation of the local participant.
        localPlayer = PlayerModel(
            id: session.localParticipant.id,
            name: appModel.playerName,
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        )
        appModel.showPlayerNameAlert = localPlayer.name.isEmpty
        
        observeRemoteParticipantUpdates()
        configureSystemCoordinator()
        
        session.join()
        
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
    
    func updateSpatialTemplatePreference() {
        switch game.stage {
            case .modeSelection, .recentGames, .sideSelection:
                systemCoordinator.configuration.spatialTemplatePreference = .custom(TeamSelectionTemplate())
            case .inSetup, .inGame, .gameOver:
                systemCoordinator.configuration.spatialTemplatePreference = .custom(GameTemplate())
        }
    }
    
    func updateLocalParticipantRole() {
        // Set and unset the participant's spatial template role based on updating game state.
        switch game.stage {
        case .modeSelection, .recentGames:
                systemCoordinator.resignRole()
            case .sideSelection:
                switch localPlayer.side {
                    case .none:
                        systemCoordinator.resignRole()
                    case .white:
                        systemCoordinator.assignRole(TeamSelectionTemplate.Role.white)
                    case .black:
                        systemCoordinator.assignRole(TeamSelectionTemplate.Role.black)
                }
        case .inGame, .inSetup, .gameOver:
                switch localPlayer.side {
                    case .none:
                        systemCoordinator.resignRole()
                    case .white:
                        systemCoordinator.assignRole(TeamSelectionTemplate.Role.white)
                    case .black:
                        systemCoordinator.assignRole(TeamSelectionTemplate.Role.black)
                }
        }
    }
    
    func configureSystemCoordinator() {
        // Let the system coordinator show each players' spatial Persona in the immersive space.
        systemCoordinator.configuration.supportsGroupImmersiveSpace = true
        
        Task {
            // Wait for gameplay updates from participants.
            for await localParticipantState in systemCoordinator.localParticipantStates {
                localPlayer.seatPose = localParticipantState.seat?.pose
            }
        }
    }

    func enterTeamSelection(gameMode: GameModel.GameMode) {
        game.stage = .sideSelection
        game.mode = gameMode
        game.moveHistory.removeAll()
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
        Task {
            if game.mode == .mixed {
                await self.startBoardConstruction()
            }
            await self.findAllFieldEntities()
            await self.findAllPieceEntities()
            
            if game.currentSide == localPlayer.side {
                let white = players.first(where: {$0.value.side == .white})?.value
                let black = players.first(where: {$0.value.side == .black})?.value
                    
                game.whitePlayer = "\(white?.deviceId ?? "0000")//\(white?.name ?? "Player")"
                game.blackPlayer = "\(black?.deviceId ?? "1111")//\(black?.name ?? "Player")"
                    
                guard let whitePlayer = game.whitePlayer, let blackPlayer = game.blackPlayer else { print(game)
                    return }
                
                let request = GameRequest(white: whitePlayer, black: blackPlayer, opponent: GameRequest.Opponent.init(rawValue: game.mode!.description.uppercased())!, opponentStrength: opponentStrength.level)
                
                GamesAPI.gamesPost(gameRequest: request, completion: { response, error in
                    if let error = error {
                        print("Error: \(error.localizedDescription)")
                        return
                    }
                    print(response ?? "response")
                    
                    self.game.stage = .inGame(.beforePlayersTurn)
                    self.localPlayer.isPlaying = true
                    self.game.gameId = response
                    self.beginTurn()
                })
            }
            self.playSoundEffect(SFX.boom)
        }
    }
    
    func beginTurn() {
        print(currentPlayer ?? "")
        guard localPlayer.isPlaying else {
            return
        }
        
        game.stage = .inGame(.duringPlayersTurn)
        
        highlightCheck()
        
        print("Begin Turn")
        
        self.currentMoveEstimate = nil
        self.activateInput()
        
        self.getBestMove { move in
            if let move = move {
                let move = move.split(separator: ",")[0]
                guard move != "(none)" else {
                    // Checkmate
                    self.setWinner(side: self.game.currentSide == .white ? .black : .white)
                    return
                }
                
                if self.suggestionLevel == .off {
                    self.playSoundEffect(SFX.notify)
                } else {
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
        guard localPlayer.isPlaying else {
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
        
        let nextSide: PlayerModel.Side = game.currentSide == .white ? .black : .white
        print(nextSide)
        
        
        localPlayer.isPlaying = false
        game.currentSide = nextSide
        game.stage = .inGame(.afterPlayersTurn)
        
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
        
        guard let gameId = self.game.gameId else { return }
        
        let updateRequest: GameUpdateRequest = GameUpdateRequest(winner: side == .white ? game.whitePlayer : game.blackPlayer)
        
        GamesAPI.gamesIdPatch(id: gameId, gameUpdateRequest: updateRequest) { response, error in
            guard error == nil else {
                return
            }
        }
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
        lastAppliedPosition = initialPosition
        game.stage = .modeSelection
    }
    
    func gameStateChanged() {
        if game.stage == .modeSelection {
            localPlayer.isPlaying = false
        }
        
        updateSpatialTemplatePreference()
        updateCurrentPlayer()
        updateLocalParticipantRole()
        
        if game.stage.isInGame {
            updateBoard()
        }
    }
    
    func updateCurrentPlayer() {
        if game.stage.isInGame, localPlayer.side == game.currentSide {
            localPlayer.isPlaying = true
        } else {
            localPlayer.isPlaying = false
        }
    }
    
    func updateBoard() {
        if game.currentSide != localPlayer.side {
            print("Update Board")
            
            let unappliedMoves = getUnappliedMoves()
            
            for (piece, destination) in unappliedMoves {
                guard let pieceEntity = pieceEntities[piece] else { continue }

                switch destination {
                    case .defeated:
                        pieceEntity.removeFromParent()
                    
                    case let targetField where piece.rawValue.hasPrefix("blackPawn") && targetField.rawValue.hasSuffix("1"):
                        Task {
                            await self.promotePawn(pawn: piece, to: .blackQueen)
                        }
                        
                    case let targetField where piece.rawValue.hasPrefix("whitePawn") && targetField.rawValue.hasSuffix("8"):
                        Task {
                            await self.promotePawn(pawn: piece, to: .whiteQueen)
                        }
                        
                    default:
                        if let fieldEntity = fieldEntities[destination] {
                            Task {
                                await self.animateMove(piece: pieceEntity, field: fieldEntity)
                            }
                        }
                    }
            }
            
            self.highlightCheck()
            self.lastAppliedPosition = self.game.lastKnownPosition
        }

        if game.currentSide == localPlayer.side && game.stage == .inGame(.afterPlayersTurn) {
            print("Begin Turn")
            currentTargetField = []
            currentlyMovingChessPiece = nil
            currentlyCapturedPieces = []
            currentlyMovingChessPieceCollisionSubscription?.cancel()
            currentlyMovingChessPieceCollisionSubscription = nil
            currentlyMovingChessPieceCollisionSubscriptionEnd?.cancel()
            currentlyMovingChessPieceCollisionSubscriptionEnd = nil
            hideAllFieldEntities()
            self.beginTurn()
        }
    }
    
    func getUnappliedMoves() -> [ChessPiece: ChessField] {
        return self.game.lastKnownPosition
            .filter { piece, field in self.lastAppliedPosition[piece] != field }
            .sorted { (first, second) in
                first.value == .defeated && second.value != .defeated
            }
            .reduce(into: [ChessPiece: ChessField]()) { dict, pair in
                dict[pair.key] = pair.value
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
            self.lastAppliedPosition[piece] = to
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
                if let piece = ChessPiece(rawValue: entity.name) {
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
        
        print("Chess piece entities found: \(pieceEntities.count)")
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
                        
                    } else if collisionEvent.entityB.name == "mesh" || collisionEvent.entityB.name.hasPrefix("Plane")  {
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
    
    func update(prediction: ChessPieceDetectionManager.ChessBoardPredictionResult) async {
        let (boundingBox, bestMaskIdx) = getBoundingBox(feature: prediction.var_1647.featureValue.multiArrayValue!)
        
        let cornerPoints = getCornerPoints(boundingBox, masks: prediction.p.featureValue.multiArrayValue!, bestMaskIdx: bestMaskIdx)
        
        // Normalize board corners
        let boardCorners = cornerPoints.map { point -> CGPoint in
                return CGPoint(x: point.x / 640, y: point.y / 640)
            }
        
        //let piecePoints = prediction.pieces.compactMap({CGPoint(x: $0.boundingBox.midX, y: (1.0 - $0.boundingBox.midY) + $0.boundingBox.height/4.0 )})
        //image = Image(uiImage: drawPointsOnImage(named: "test", normalizedPoints: boardCorners + piecePoints)!)
        

        // Destination points for a flat 8x8 board
        let destination: [CGPoint] = [
            CGPoint(x: 0, y: 0),   // top-left
            CGPoint(x: 1, y: 0),   // top-right
            CGPoint(x: 1, y: 1),   // bottom-right
            CGPoint(x: 0, y: 1)    // bottom-left
        ]

        // Final board representation: 8 rows of 8 columns (row-major, top to bottom)
        //var board = Array(repeating: Array(repeating: nil as String?, count: 8), count: 8)
        var positionEstimate: [ChessField: ChessPieceDetectionManager.PredictionResult.Label] = [:]
        
        if let perspectiveTransform = PerspectiveTransform(source: boardCorners, destination: destination), let side = localPlayer.side {
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
                
                let chessField = ChessField.fromArrayIndicies(x: boardX, y: boardY, side: side)
                
                if let chessField = chessField, positionEstimate[chessField] == nil {
                    //print("Piece: \(piece.label.rawValue), BoardX: \(boardX), BoardY: \(boardY), chessField: \(chessField)")
                    positionEstimate[chessField] = piece.label
                }
            }
        } else {
            print("Failed to compute perspective transform.")
        }

        let move = await detectPhysicalMove(lastKnownPosition: game.lastKnownPosition, positionEstimate: positionEstimate)
        
        if let move = move, let gameId = game.gameId {
            GamesAPI.gamesIdMoveValidMoveGet(id: gameId, move: move) { response, error in
                guard error == nil else {
                    print("Error validating move: \(move) - \(error!.localizedDescription)")
                    return
                }
                
                print(move)
                self.currentMoveEstimate = move
            }
        } else {
            print("No move detected")
        }
    }
    
    func applyPhysicalMove() {
        if let currentMoveEstimate = currentMoveEstimate {
            let from = ChessField(rawValue: String(currentMoveEstimate.prefix(2)))
            // Get characters at index 2 and 3 (3rd and 4th characters)
            let startIndex = currentMoveEstimate.index(currentMoveEstimate.startIndex, offsetBy: 2)
            let endIndex = currentMoveEstimate.index(startIndex, offsetBy: 2)
            let to = ChessField(rawValue: String(currentMoveEstimate[startIndex..<endIndex]))
            
            let chessPiece = game.lastKnownPosition.first(where: {$0.value == from})?.key
            if let chessPiece = chessPiece, let to = to {
                self.moveRequestPending = true
                move(piece: chessPiece, to: to, promotedPiece: nil) { success in
                    if !success {
                        print("Return piece to initial position")
                    }
                    self.moveRequestPending = false
                    self.currentMoveEstimate = nil
                }
            }
        }
        
    }
    
    
    func resetAlert() {
            self.alert = nil
        }
}
