package de.timbachmann.api.routes

import de.timbachmann.api.engine.Client
import de.timbachmann.api.model.request.GameRequest
import de.timbachmann.api.model.request.MoveRequest
import de.timbachmann.api.model.response.MoveResponse
import de.timbachmann.api.repository.interfaces.GameRepositoryInterface
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import org.bson.types.ObjectId
import org.koin.ktor.ext.inject

/**
 * Defines the game-related routes for the Ktor application.
 * This includes game creation, retrieval, deletion, updating, move handling, and AI move suggestions.
 */
fun Route.gameRouting() {

    val repository by inject<GameRepositoryInterface>()

    route("/games") {
        /**
         * Retrieves all games from the repository.
         */
        get {
            repository.getAll().let {
                call.respond(it.map{obj -> obj.toResponse()})
            }
        }

        /**
         * Retrieves a specific game by ID.
         */
        get("/{id?}") {
            val id = call.parameters["id"]
            if (id.isNullOrEmpty()) {
                return@get call.respondText(
                    text = "Missing id",
                    status = HttpStatusCode.BadRequest
                )
            }
            repository.findById(ObjectId(id))?.let {
                call.respond(it.toResponse())
            } ?: call.respond(HttpStatusCode.NotFound, "No records found for id $id")
        }

        /**
         * Creates a new game and inserts it into the repository.
         */
        post {
            val newGame = call.receive<GameRequest>()
            val insertedId = repository.insertOne(newGame.toGameObject())
            if (insertedId != null) {
                call.respond(HttpStatusCode.Created, "${insertedId.asObjectId().value}")
            } else {
                call.respond(HttpStatusCode.BadRequest, "Cannot post a new game")
            }
        }

        /**
         * Deletes a game by ID.
         */
        delete("/{id?}") {
            val id = call.parameters["id"] ?: return@delete call.respondText(
                text = "Missing game id",
                status = HttpStatusCode.BadRequest
            )
            val delete: Long = repository.deleteById(ObjectId(id))
            if (delete == 1L) {
                return@delete call.respondText("Game Deleted successfully", status = HttpStatusCode.OK)
            }
            return@delete call.respondText("Game not found", status = HttpStatusCode.NotFound)
        }

        /**
         * Updates a game by ID.
         */
        put("/{id?}") {
            val id = call.parameters["id"] ?: return@put call.respondText(
                text = "Missing game id",
                status = HttpStatusCode.BadRequest
            )
            val gameRequest = call.receive<GameRequest>()
            val updated = repository.updateOne(ObjectId(id), gameRequest.toGameObject())
            call.respondText(
                text = if (updated.wasAcknowledged()) "Game updated successfully" else updated.toString(),
                status = if (updated.wasAcknowledged()) HttpStatusCode.OK else HttpStatusCode.InternalServerError
            )
        }

        /**
         * Retrieves the best move for a given game state using client engine.
         * @see Client
         */
        get("/{id?}/bestMove") {
            val gameId = call.parameters["id"]
            if (gameId.isNullOrEmpty()) {
                return@get call.respondText(
                    text = "Missing GameId",
                    status = HttpStatusCode.BadRequest
                )
            }
            repository.findById(ObjectId(gameId))?.let { game ->
                val currentPosition = game.gameState
                val level = game.opponentStrength

                val client = Client()
                client.initUci(level)
                client.setPosition(currentPosition)
                val side = client.getSideToMove(currentPosition)
                client.getCurrentBestMove()?.let { bestMove ->
                    client.close()
                    return@get call.respond(HttpStatusCode.Created, "$bestMove, $side")
                } ?: {
                    client.close()
                }
                return@get call.respondText("No best move found for id $gameId", status = HttpStatusCode.NotFound)
            } ?:return@get call.respondText("No game found for id $gameId", status = HttpStatusCode.NotFound)
        }

        /**
         * Processes a player's move and updates the game state accordingly.
         */
        post("/{id?}/move") {
            val moveRequest = call.receive<MoveRequest>()
            val gameId = call.parameters["id"]
            if (gameId.isNullOrEmpty()) {
                return@post call.respondText(
                    text = "Missing GameId",
                    status = HttpStatusCode.BadRequest
                )
            }
            repository.findById(ObjectId(gameId))?.let { game ->
                val currentPosition = game.gameState
                val level = game.opponentStrength

                val client = Client()
                client.initUci(level)
                val moveSucceeded = client.move(moveRequest.move, currentPosition)
                if (moveSucceeded) {
                    client.getCurrentPosition()?.let { newPosition ->
                        game.gameState = newPosition.gameState
                        game.checkers = newPosition.checkers

                        game.moves = game.moves.plus(moveRequest.move)
                        val updated = repository.updateOne(game.id, game)

                        if (!updated.wasAcknowledged()) {
                            client.close()
                            return@post call.respondText("Game state not updated for id $gameId", status = HttpStatusCode.InternalServerError)
                        }
                        client.close()
                        return@post call.respond(HttpStatusCode.Created, MoveResponse(moveSucceeded = true, newGameState = newPosition))
                    } ?: return@post call.respondText("Game state not updated for id $gameId", status = HttpStatusCode.InternalServerError)
                }
                return@post call.respondText("Move {${moveRequest.move}} not valid for state {${game.gameState}}", status = HttpStatusCode.BadRequest)
            } ?:return@post call.respondText("No game found for id $gameId", status = HttpStatusCode.NotFound)
        }
    }
}
