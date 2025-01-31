package de.timbachmann.api.model.request

/**
 * Data class representing a request to make a move in a game.
 *
 * @property move The move notation (e.g., "e2e4" for chess moves).
 */
data class MoveRequest(
    val move: String,
)
