//
//  Enums.swift
//  VisionChess
//
//  Created by Tim Bachmann on 02.03.2025.
//

import RealityKit
import Foundation
import ARKit

enum Side: String, CaseIterable {
    case white = "w"
    case black = "b"

    static func byFenNotation(_ input: String) -> Side? {
        return Side.allCases.first { $0.rawValue.caseInsensitiveCompare(input) == .orderedSame }
    }
}

enum ChessPiece: String, Codable {
    case blackKing
    case blackQueen
    case blackBishopC
    case blackBishopF
    case blackKnightB
    case blackKnightG
    case blackRookA
    case blackRookH
    case blackPawnA
    case blackPawnB
    case blackPawnC
    case blackPawnD
    case blackPawnE
    case blackPawnF
    case blackPawnG
    case blackPawnH
    case whiteKing
    case whiteQueen
    case whiteBishopC
    case whiteBishopF
    case whiteKnightB
    case whiteKnightG
    case whiteRookA
    case whiteRookH
    case whitePawnA
    case whitePawnB
    case whitePawnC
    case whitePawnD
    case whitePawnE
    case whitePawnF
    case whitePawnG
    case whitePawnH
}

enum ChessField: String, Codable {
    case a1
    case a2
    case a3
    case a4
    case a5
    case a6
    case a7
    case a8
    
    case b1
    case b2
    case b3
    case b4
    case b5
    case b6
    case b7
    case b8
    
    case c1
    case c2
    case c3
    case c4
    case c5
    case c6
    case c7
    case c8
    
    case d1
    case d2
    case d3
    case d4
    case d5
    case d6
    case d7
    case d8
    
    case e1
    case e2
    case e3
    case e4
    case e5
    case e6
    case e7
    case e8
    
    case f1
    case f2
    case f3
    case f4
    case f5
    case f6
    case f7
    case f8
    
    case g1
    case g2
    case g3
    case g4
    case g5
    case g6
    case g7
    case g8
    
    case h1
    case h2
    case h3
    case h4
    case h5
    case h6
    case h7
    case h8
    
    case defeated
}

enum ChessPieceFen: String, CaseIterable {
    case blackKing = "k"
    case blackQueen = "q"
    case blackBishop = "b"
    case blackKnight = "n"
    case blackRook = "r"
    case blackPawn = "p"
    case whiteKing = "K"
    case whiteQueen = "Q"
    case whiteBishop = "B"
    case whiteKnight = "N"
    case whiteRook = "R"
    case whitePawn = "P"
}

let initialPosition: [ChessPiece: ChessField] = [
    .blackKing: .e8,
    .blackQueen: .d8,
    .blackBishopC: .c8,
    .blackBishopF: .f8,
    .blackKnightB: .b8,
    .blackKnightG: .g8,
    .blackRookA: .a8,
    .blackRookH: .h8,
    .blackPawnA: .a7,
    .blackPawnB: .b7,
    .blackPawnC: .c7,
    .blackPawnD: .d7,
    .blackPawnE: .e7,
    .blackPawnF: .f7,
    .blackPawnG: .g7,
    .blackPawnH: .h7,
    .whiteKing: .e1,
    .whiteQueen: .d1,
    .whiteBishopC: .c1,
    .whiteBishopF: .f1,
    .whiteKnightB: .b1,
    .whiteKnightG: .g1,
    .whiteRookA: .a1,
    .whiteRookH: .h1,
    .whitePawnA: .a2,
    .whitePawnB: .b2,
    .whitePawnC: .c2,
    .whitePawnD: .d2,
    .whitePawnE: .e2,
    .whitePawnF: .f2,
    .whitePawnG: .g2,
    .whitePawnH: .h2,
]


let chessPieceToModel: [String: String] = [
    "blackKing": "black-king",
    "blackQueen": "black-queen",
    "blackBishop": "black-bishop",
    "blackKnight": "black-knight",
    "blackRook": "black-rook",
    "blackPawn": "black-pawn",
    "whiteKing": "white-king",
    "whiteQueen": "white-queen",
    "whiteBishop": "white-bishop",
    "whiteKnight": "white-knight",
    "whiteRook": "white-rook",
    "whitePawn": "white-pawn"
]

protocol AnchorableEntity {
    var worldAnchorID: UUID? { get set }
    var renderContent: RealityKit.Entity? { get }
    var debugDescription: String { get }
}

protocol PlaneAnchoringDataSource {
    func renderContentForAnchor(_ worldAnchor: WorldAnchor) -> Entity?
    func renderContentForAnchor(_ id: UUID) -> Entity?
    func insertInstance(_ entity: AnchorableEntity, id: UUID)
    func shouldRemoveEntity(for id: UUID) -> Bool
}

enum GameEntityResource {
    case blackKing
    case blackQueen
    case blackBishop
    case blackKnight
    case blackRook
    case blackPawn
    case whiteKing
    case whiteQueen
    case whiteBishop
    case whiteKnight
    case whiteRook
    case whitePawn
}

enum ViewState: CaseIterable {
    case initializing, preGame, inModeSelection, inGameMenu, setup, playing, gameOver
}

enum GameAudioResource {
    case backgroundMusic
    case pop
    case ping
    case highscore
}
