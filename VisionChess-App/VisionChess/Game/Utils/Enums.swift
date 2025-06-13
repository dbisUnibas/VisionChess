//
//  Enums.swift
//  VisionChess
//
//  Created by Tim Bachmann on 02.03.2025.
//

import RealityKit
import Foundation
import ARKit


struct Tutorial: Decodable {
    let steps: [TutorialStep]
}

struct TutorialStep: Decodable {
    let text: String
    let piece: String?
    let desiredMove: String?
    let opponentMove: String?
    let highlightedFields: [String]?
}

enum ChessPiece: String, CaseIterable, Codable {
    case blackKing
    case blackQueen
    case blackBishopC, blackBishopF
    case blackKnightB, blackKnightG
    case blackRookA, blackRookH
    case blackPawnA, blackPawnB, blackPawnC, blackPawnD, blackPawnE, blackPawnF, blackPawnG, blackPawnH
    
    case whiteKing
    case whiteQueen
    case whiteBishopC,whiteBishopF
    case whiteKnightB,whiteKnightG
    case whiteRookA,whiteRookH
    case whitePawnA, whitePawnB, whitePawnC, whitePawnD, whitePawnE, whitePawnF, whitePawnG, whitePawnH
}

enum ChessField: String, CaseIterable, Codable {
    case a1, a2, a3, a4, a5, a6, a7, a8
    case b1, b2, b3, b4, b5, b6, b7, b8
    case c1, c2, c3, c4, c5, c6, c7, c8
    case d1, d2, d3, d4, d5, d6, d7, d8
    case e1, e2, e3, e4, e5, e6, e7, e8
    case f1, f2, f3, f4, f5, f6, f7, f8
    case g1, g2, g3, g4, g5, g6, g7, g8
    case h1, h2, h3, h4, h5, h6, h7, h8
    
    case defeated
    
    static func fromArrayIndicies(x: Int, y: Int, side: PlayerModel.Side) -> ChessField? {
        guard x >= 0 && x < 8 && y >= 0 && y < 8 else { return nil }
        let xLetters: [String] = ["a", "b", "c", "d", "e", "f", "g", "h"]
        let xLetter = side == .white ? xLetters[x] : xLetters[7 - x]
        let yString = side == .white ? String(8 - y) : String(y + 1)
        return ChessField(rawValue: xLetter + yString)
    }
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
    
    static func fromLowerCased(moveNotation: String, side: PlayerModel.Side) -> ChessPieceFen? {
        let letter = side == .white ? moveNotation.uppercased() : moveNotation.lowercased()
        
        guard let piece = ChessPieceFen(rawValue: letter) else {
            return nil
        }
        
        return piece
    }
}

extension ChessPieceFen: CustomStringConvertible {
    var description: String {
        switch self {
            case .blackKing: return "blackKing"
            case .blackQueen: return "blackQueen"
            case .blackBishop: return "blackBishop"
            case .blackKnight: return "blackKnight"
            case .blackRook: return "blackRook"
            case .blackPawn: return "blackPawn"
            case .whiteKing: return "whiteKing"
            case .whiteQueen: return "whiteQueen"
            case .whiteBishop: return "whiteBishop"
            case .whiteKnight: return "whiteKnight"
            case .whiteRook: return "whiteRook"
            case .whitePawn: return "whitePawn"
        }
    }
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

enum CastlingMove: String, CaseIterable, Codable {
    case kingsideWhite = "e1g1"
    case kingsideBlack = "e8g8"
    case queensideWhite = "e1c1"
    case queensideBlack = "e8c8"
}

struct CastlingInfo {
    let rookPiece: ChessPiece
    let targetField: ChessField
}

let castlingMap: [CastlingMove: CastlingInfo] = [
    .kingsideBlack: .init(rookPiece: .blackRookH, targetField: .f8),
    .kingsideWhite: .init(rookPiece: .whiteRookH, targetField: .f1),
    .queensideBlack: .init(rookPiece: .blackRookA, targetField: .d8),
    .queensideWhite: .init(rookPiece: .whiteRookA, targetField: .d1)
]

enum SFX: String, Codable {
    case boom = "boom"
    case capture = "capture"
    case castle = "castle"
    case lose = "game-lose"
    case win = "game-win"
    case check = "move-check"
    case moveOpponent = "move-opponent"
    case moveSelf = "move-self"
    case notify = "notify"
    case promotion = "promote"
    case select = "select"
    case pickUp = "pick-up"
}

// Convert a specific ChessPiece to its generic Label.
func label(for piece: ChessPiece) -> ChessPieceDetectionManager.PredictionResult.Label? {
    let raw = piece.rawValue.lowercased()
    if raw.contains("whitepawn") { return .whitePawn }
    if raw.contains("whiteking") { return .whiteKing }
    if raw.contains("whitequeen") { return .whiteQueen }
    if raw.contains("whitebishop") { return .whiteBishop }
    if raw.contains("whiteknight") { return .whiteKnight }
    if raw.contains("whiterook") { return .whiteRook }
    
    if raw.contains("blackpawn") { return .blackPawn }
    if raw.contains("blackking") { return .blackKing }
    if raw.contains("blackqueen") { return .blackQueen }
    if raw.contains("blackbishop") { return .blackBishop }
    if raw.contains("blackknight") { return .blackKnight }
    if raw.contains("blackrook") { return .blackRook }
    return nil
}
