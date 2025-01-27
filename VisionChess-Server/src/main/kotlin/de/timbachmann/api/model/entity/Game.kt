package de.timbachmann.api.model.entity

import de.timbachmann.api.model.response.GameResponse
import org.bson.codecs.pojo.annotations.BsonId
import org.bson.types.ObjectId

data class Game(
    @BsonId
    val id: ObjectId,
    val gameState: String,
    val moves: List<ObjectId>,
    val white: String,
    val black: String,
    val opponent: ChessOpponent,
    val winner: ObjectId?,
){
    fun toResponse() = GameResponse(
        id = id.toString(),
        gameState = gameState,
        moves = moves.map { it.toString() },
        white = white,
        black = black,
        opponent = opponent,
        winner = winner.toString()
    )
}