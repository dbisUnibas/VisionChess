package de.timbachmann.api.model.request

import de.timbachmann.api.model.entity.ChessOpponent
import de.timbachmann.api.model.entity.Game
import org.bson.types.ObjectId

data class GameRequest(
    val white: String,
    val black: String,
    val opponent: ChessOpponent
) {
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