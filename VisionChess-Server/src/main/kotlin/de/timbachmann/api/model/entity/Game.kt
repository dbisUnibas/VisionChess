package de.timbachmann.api.model.entity

import de.timbachmann.api.model.response.GameResponse
import org.bson.codecs.pojo.annotations.BsonId
import org.bson.types.ObjectId

/**
 * Data class representing a game entity stored in the database.
 *
 * @property id The unique identifier of the game.
 * @property gameState The current state of the game in FEN notation.
 * @property moves A list of moves made in the game.
 * @property white The player controlling the white pieces.
 * @property black The player controlling the black pieces.
 * @property opponent The opponent type, represented by {@link ChessOpponent}.
 * @property winner The player who won the game (if applicable).
 */
data class Game(
    @BsonId
    val id: ObjectId,
    var gameState: String,
    var moves: List<String>,
    val white: String,
    val black: String,
    val opponent: ChessOpponent,
    val winner: String,
) {
    /**
     * Converts the `Game` entity to a `GameResponse` object for API responses.
     *
     * @return A `GameResponse` representation of this `Game` entity.
     */
    fun toResponse() = GameResponse(
        id = id.toString(),
        gameState = gameState,
        moves = moves,
        white = white,
        black = black,
        opponent = opponent,
        winner = winner
    )
}
