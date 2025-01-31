package de.timbachmann.api.model.entity

/**
 * Enum representing different types of chess opponents.
 */
enum class ChessOpponent {
    /** A human opponent playing physically. */
    PHYSICAL,

    /** A human opponent playing virtually. */
    MIXED,

    /** A fully virtual engine opponent. */
    VIRTUAL
}
