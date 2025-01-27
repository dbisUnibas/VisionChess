package de.timbachmann.api.model.response

import de.timbachmann.api.model.entity.ChessOpponent


data class GameResponse(
    val id: String,
    val gameState: String,
    val moves: List<String>,
    val white: String,
    val black: String,
    val opponent: ChessOpponent,
    val winner: String
)