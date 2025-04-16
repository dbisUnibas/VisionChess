package de.timbachmann.api.model.response

import de.timbachmann.api.engine.GameState

data class MoveResponse(
    val moveSucceeded: Boolean,
    val newGameState: GameResponse
)
