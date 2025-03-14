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
import OpenAPIClient

@Observable @MainActor
final class SessionController: GameControllerProtocol {
    let session: GroupSession<ChessGroupActivity>
    let messenger: GroupSessionMessenger
    let systemCoordinator: SystemCoordinator

    var opponentStregth: GameModel.OpponentStrength = .medium
    
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
            name: appModel.playerName
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
    
    func updateSpatialTemplatePreference() {
        switch game.stage {
            case .modeSelection:
                systemCoordinator.configuration.spatialTemplatePreference = .sideBySide
            case .sideSelection:
                systemCoordinator.configuration.spatialTemplatePreference = .custom(TeamSelectionTemplate())
            case .inSetup:
                systemCoordinator.configuration.spatialTemplatePreference = .custom(GameTemplate())
            case .inGame:
                systemCoordinator.configuration.spatialTemplatePreference = .custom(GameTemplate())
            case .gameOver:
                systemCoordinator.configuration.spatialTemplatePreference = .custom(GameTemplate())
        }
    }
    
    func updateLocalParticipantRole() {
        // Set and unset the participant's spatial template role based on updating game state.
        switch game.stage {
            case .modeSelection:
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
    
    func joinTeam(_ side: PlayerModel.Side?) {
        localPlayer.side = side
    }
    
    func startSetup() {
        game.stage = .inSetup
    }
    
    func startGame() {
        game.stage = .inGame(.beforePlayersTurn)
    }
    
    func beginTurn() {
        game.stage = .inGame(.duringPlayersTurn)
        
        if !game.checkers.isEmpty {
            game.checkers.forEach { checker in
                let checkerFieldEntity = self.fieldEntities[checker]
                
                if let checkerFieldEntity = checkerFieldEntity {
                    checkerFieldEntity.components[OpacityComponent.self]?.opacity = 1
                }
            }
        }
        
        if (game.currentSide == localPlayer.side && localPlayer.isPlaying) {
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
                        let chessFieldFromEntity = self.fieldEntities[from]
                        let chessFieldToEntity = self.fieldEntities[to]
                        
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
        guard game.stage.isInGame, localPlayer.isPlaying else {
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
        
        // self.setWinner(side: self.game.currentSide)
        
        game.stage = .inGame(.beforePlayersTurn)
        game.currentSide = game.currentSide == .white ? .black : .white
        
        print(game.currentSide)
        self.beginTurn()
        
        if game.currentSide != localPlayer.side {
            localPlayer.isPlaying = false
        }
    }
    
    func endGame() {
        game.stage = .modeSelection
        game.gameStateFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        game.currentSide = .white
    }
    
    func setWinner(side: PlayerModel.Side) {
        game.winner = side
        game.stage = .gameOver
    }
    
    func gameStateChanged() {
        if game.stage == .modeSelection {
            localPlayer.isPlaying = false
            localPlayer.score = 0
        }
        
        updateSpatialTemplatePreference()
        updateCurrentPlayer()
        updateLocalParticipantRole()
        updateBoard()
    }
    
    func updateCurrentPlayer() {
        if game.stage.isInGame, localPlayer.side == game.currentSide {
            localPlayer.isPlaying = true
        }
    }
    
    var currentPlayer: PlayerModel? {
        players.values.first(where: \.isPlaying)
    }
    
    var activeTeam: PlayerModel.Side? {
        return currentPlayer?.side
    }
    
    
    func updateBoard() {
        let unappliedMoves = getUnappliedMoves()
        for move in unappliedMoves {
            if let fieldEntity = fieldEntities[move.value], let pieceEntity = pieceEntities[move.key] {
                if move.value == .defeated {
                    pieceEntity.removeFromParent()
                }
                Task {
                    await self.animateMove(piece: pieceEntity, field: fieldEntity)
                }
            }
        }
        self.lastAppliedPosition = self.game.lastKnownPosition
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
    
    // GameControllerProtocol
    
    func startGame(opponentStrength: GameModel.OpponentStrength) {
        game.stage = .inGame(.beforePlayersTurn)
        
        Task {
            await self.findAllFieldEntities()
            await self.findAllPieceEntities()
            
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
            self.game.gameStateFen = response?.gameState ?? self.game.gameStateFen
            self.game.moveHistory = response?.moves ?? self.game.moveHistory
            self.game.checkers = response?.checkers.compactMap { ChessField(rawValue: $0) } ?? self.game.checkers
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
                    
                    self.lastAppliedPosition[piece] = to
                    self.game.lastKnownPosition[piece] = to
                    
                    self.removeDefeatedPieces(at: to)
                    
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
        let downTransform = Transform(translation: SIMD3(0, -0.05, 0))
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
    
    func setPlaneToProjectOnFound(value: Bool) {
        planeToProjectOnFound = value
    }
    
    func setPlacementLocationTransform(value: Transform) {
        placementLocation.transform = value
    }
    
    func setCurrentlyMovingChessPiece(entity: Entity) {
        currentlyMovingChessPiece = entity
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
        await waitForEntities(named: ["black", "white"])
        
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
                    print(piece)
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
    
    func hideAllFieldEntities() {
        for chessField in ChessField.allCases {
            if let entity = self.fieldEntities[chessField] {
                entity.components[OpacityComponent.self]?.opacity = 0.0
            }
        }
    }
    
}
