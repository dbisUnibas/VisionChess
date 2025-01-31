package de.timbachmann.api.model.request

import de.timbachmann.api.model.entity.ChessOpponent
import de.timbachmann.api.model.entity.Game
import org.bson.types.ObjectId

/**
 * Data class representing a request to create a new game.
 *
 * @property white The player controlling the white pieces.
 * @property black The player controlling the black pieces.
 * @property opponent The opponent type, represented by {@link ChessOpponent}.
 */
data class GameRequest(
    val white: String,
    val black: String,
    val opponent: ChessOpponent
) {

    /**
     * Converts the `GameRequest` object to a `Game` entity for database storage.
     *
     * @return A new {@link Game} object with a generated ID, default game state, and no moves.
     */
    fun toGameObject(): Game {
        return Game(
            id = ObjectId(),
            gameState = "startpos",
            moves = listOf(),
            white = white,
            black = black,
            opponent = opponent,
            winner = "null"
        )
    }
}
