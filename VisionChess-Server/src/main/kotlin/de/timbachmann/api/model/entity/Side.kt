package de.timbachmann.api.model.entity

/**
 * Enum representing the two sides in a chess game.
 */
enum class Side {
    WHITE, BLACK;

    companion object {
        /**
         * Retrieves the corresponding `Side` based on FEN notation.
         *
         * @param input The FEN notation character representing the side ("w" for WHITE, "b" for BLACK).
         * @return The corresponding `Side`, or `null` if the input is invalid.
         */
        fun byFenNotation(input: String): Side? {
            return entries.firstOrNull { it.name.substring(0, 1).equals(input, true) }
        }
    }
}
