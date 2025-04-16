package de.timbachmann.api.model.request

import de.timbachmann.api.model.entity.ChessOpponent
import de.timbachmann.api.model.entity.Game


data class GameUpdateRequest(
    val gameState: String? = null,
    val moves: List<String>? = null,
    val white: String? = null,
    val black: String? = null,
    val checkers: List<String>? = null,
    val opponent: ChessOpponent? = null,
    val opponentStrength: Int? = null,
    val winner: String? = null
) {

    companion object {
        /**
         * Creates a GameUpdateRequest from a full Game entity.
         *
         * @param game The game object to convert.
         * @return A new GameUpdateRequest with properties copied from the game.
         */
        fun fromGameObject(game: Game): GameUpdateRequest {
            return GameUpdateRequest(
                gameState = game.gameState,
                moves = game.moves,
                white = game.white,
                black = game.black,
                checkers = game.checkers,
                opponent = game.opponent,
                opponentStrength = game.opponentStrength,
                winner = game.winner
            )
        }
    }
}
