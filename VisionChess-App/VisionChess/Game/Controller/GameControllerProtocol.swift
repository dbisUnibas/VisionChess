//
//  GameControllerProtocol.swift
//  VisionChess
//
//  Created by Tim Bachmann on 12.03.2025.
//

import RealityKit
import SwiftUI

@MainActor
protocol GameControllerProtocol {
    var opponentStregth: GameModel.OpponentStrength { get set }
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

    func enterTeamSelection(gameMode: GameModel.GameMode)
    func joinTeam(_ side: PlayerModel.Side?)
    func startSetup()
    func startGame(opponentStrength: GameModel.OpponentStrength)
    func beginTurn()
    func endTurn()
    func endGame()
    func setWinner(side: PlayerModel.Side)
    func gameStateChanged()
    func updateGameState()
    func pieceAt(field: String) -> ChessPieceFen?
    func getFieldEntityFromChessPieceEntity(_ chessPieceEntity: Entity) -> Entity?
    func getBestMove(completion: @escaping (String?) -> Void)
    func move(piece: ChessPiece, to: ChessField, completion: @escaping (Bool) -> Void)
    func getPieceByField(field: ChessField) -> ChessPiece?
    func animateMove(piece: Entity, field: Entity)
    func getDefeatedPieces(side: String) -> [String]
    func moveCube(entity: Entity, to: SIMD3<Float>)
    func isValidChessField(field: String) -> Bool
    func isValidChessPiece(piece: String) -> Bool
    func deactivateInput()
    func activateInput()
    func handleCollisions(content: RealityViewContent)
    func setPlaneToProjectOnFound(value: Bool)
    func setPlacementLocationTransform(value: Transform)
    func setCurrentlyMovingChessPiece(entity: Entity)
}
