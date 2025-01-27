package de.timbachmann.api.model.entity

enum class Side {
    WHITE, BLACK;

    companion object {
        fun byFenNotation(input: String): Side? {
            return entries.firstOrNull { it.name.substring(0, 1).equals(input, true) }
        }
    }
}