package de.timbachmann.api.model.entity

import de.timbachmann.api.model.response.GameResponse
import org.bson.codecs.pojo.annotations.BsonId
import org.bson.types.ObjectId

data class Game(
    @BsonId
    val id: ObjectId,
    var gameState: String,
    var moves: List<String>,
    val white: String,
    val black: String,
    val opponent: ChessOpponent,
    val winner: String,
){
    fun toResponse() = GameResponse(
        id = id.toString(),
        gameState = gameState,
        moves = moves,
        white = white,
        black = black,
        opponent = opponent,
        winner = winner
    )
}