package de.timbachmann.api.model.entity

enum class SuggestionLevel(val rating: Int) {
    LEVEL_1(600),
    LEVEL_2(800),
    LEVEL_3(1200),
    LEVEL_4(1700),
    LEVEL_5(2000);

    companion object {
        fun fromLevel(level: Int): String {
            return when (level) {
                1 -> LEVEL_1.rating.toString()
                2 -> LEVEL_2.rating.toString()
                3 -> LEVEL_3.rating.toString()
                4 -> LEVEL_4.rating.toString()
                5 -> LEVEL_5.rating.toString()
                else -> "Unknown level"
            }
        }
    }
}