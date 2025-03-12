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

@Observable @MainActor
final class SessionController: GameControllerProtocol {
    let session: GroupSession<ChessGroupActivity>
    let messenger: GroupSessionMessenger
    let systemCoordinator: SystemCoordinator
    
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
    
    // GameControllerProtocol
    
    var opponentStregth: GameModel.OpponentStrength = .medium
    
    var currentTargetField: [Entity] = []
    var currentlyMovingChessPiece: Entity? = nil
    var currentlyMovingChessPieceCollisionSubscription: EventSubscription? = nil
    var currentlyMovingChessPieceCollisionSubscriptionEnd: EventSubscription? = nil
    
    var contentEntity = Entity()
    var deviceLocation: Entity = .init()
    var raycastOrigin: Entity = .init()
    var placementLocation: Entity = .init()
    
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
    }
    
    func endTurn() {
        guard game.stage.isInGame, localPlayer.isPlaying else {
            return
        }
        
        game.moveHistory.append(session.localParticipant.id)
        game.currentSide = game.currentSide == .white ? .black : .white
        game.stage = .inGame(.beforePlayersTurn)
        
        if game.currentSide != localPlayer.side {
            localPlayer.isPlaying = false
        }
    }
    
    func endGame() {
        game.stage = .modeSelection
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
    
    
    
    
    
    
    
    
    
    
    // GameControllerProtocol
    
    func startGame(opponentStrength: GameModel.OpponentStrength) {
        
    }
    
    func updateGameState() {
        
    }
    
    func pieceAt(field: String) -> ChessPieceFen? {
        return nil
    }
    
    func getFieldEntityFromChessPieceEntity(_ chessPieceEntity: Entity) -> Entity? {
        return nil
    }
    
    func getBestMove(completion: @escaping (String?) -> Void) {
        
    }
    
    func move(piece: ChessPiece, to: ChessField, completion: @escaping (Bool) -> Void) {
        
    }
    
    func getPieceByField(field: ChessField) -> ChessPiece? {
        return nil
    }
    
    func animateMove(piece: Entity, field: Entity) {
        
    }
    
    func getDefeatedPieces(side: String) -> [String] {
        return []
    }
    
    func moveCube(entity: Entity, to: SIMD3<Float>) {
        
    }
    
    func isValidChessField(field: String) -> Bool {
        return false
    }
    
    func isValidChessPiece(piece: String) -> Bool {
        return false
    }
    
    func deactivateInput() {
        
    }
    
    func activateInput() {
        
    }
    
    func handleCollisions(content: RealityViewContent) {
        
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
    
}
