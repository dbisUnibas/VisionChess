package de.timbachmann.api.model.response

import de.timbachmann.api.model.entity.ChessOpponent

/**
 * Data class representing the response for a game.
 *
 * @property id The unique identifier of the game.
 * @property gameState The current state of the game in FEN notation.
 * @property moves A list of moves made in the game.
 * @property white The player controlling the white pieces.
 * @property black The player controlling the black pieces.
 * @property opponent The opponent type, represented by {@link ChessOpponent}.
 * @property winner The player who won the game (if applicable).
 */
data class GameResponse(
    val id: String,
    val gameState: String,
    val moves: List<String>,
    val white: String,
    val black: String,
    val checkers: List<String>,
    val opponentStrength: Int,
    val opponent: ChessOpponent,
    val winner: String
)
