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
            gameState = "8/3P3k/n2K3p/2p3n1/1b4N1/2p1p1P1/8/3B4 w - - 0 1 moves g4f6 h7g7 f6h5 g7g6 d1c4",
            moves = listOf(),
            white = white,
            black = black,
            opponent = opponent,
            winner = null
        )
    }
}