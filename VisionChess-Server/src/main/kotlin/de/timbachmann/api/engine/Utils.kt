package de.timbachmann.api.engine

import de.timbachmann.api.model.entity.Side

/**
 * Validates if a given FEN (Forsyth-Edwards Notation) string has a correct syntax.
 *
 * @param fen The FEN string to validate.
 * @return `true` if the FEN string is valid, `false` otherwise.
 */
fun isFenSyntaxValid(fen: String): Boolean {
    if (fen == "startpos") return true

    // Regex pattern to validate the FEN structure
    val fenPattern = Regex(
        "\\s*^(((?:[rnbqkpRNBQKP1-8]+/){7})[rnbqkpRNBQKP1-8]+)\\s([b|w])\\s(-|[K|Q|k|q]{1,4})\\s(-|[a-h][1-8])\\s(\\d+\\s\\d+)$"
    )

    if (!fenPattern.matches(fen)) return false

    val fenFields = fen.split(" ")

    if (fenFields.size != 6 ||
        fenFields[0].split("/").size != 8 ||
        !fenFields[0].contains("K") ||
        !fenFields[0].contains("k") ||
        !fenFields[4].all { it.isDigit() } ||
        !fenFields[5].all { it.isDigit() } ||
        fenFields[4].toInt() >= fenFields[5].toInt() * 2
    ) {
        return false
    }

    val pieceChars = "rnbqkpRNBQKP"

    for (fenPart in fenFields[0].split("/")) {
        var fieldSum = 0
        var previousWasDigit = false
        for (c in fenPart) {
            when (c) {
                in '1'..'8' -> {
                    if (previousWasDigit) return false // Two consecutive digits are not allowed
                    fieldSum += c.toString().toInt()
                    previousWasDigit = true
                }
                in pieceChars -> {
                    fieldSum++
                    previousWasDigit = false
                }
                else -> return false // Invalid character
            }
        }
        if (fieldSum != 8) return false // Each row must contain exactly 8 columns
    }

    return true
}

/**
 * Extracts the side to move from a given FEN string.
 *
 * @param fen The FEN string to extract the side to move from.
 * @return The corresponding {@link Side} (`WHITE` or `BLACK`), or `null` if the FEN is invalid.
 */
fun getSideToMoveFromFen(fen: String): Side? {
    if (!isFenSyntaxValid(fen)) return null
    val sideToMoveFen = fen.split(" ")[1]
    return Side.byFenNotation(sideToMoveFen)
}
