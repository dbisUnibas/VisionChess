package de.timbachmann.api.repository

import com.mongodb.MongoException
import com.mongodb.client.model.Filters
import com.mongodb.client.model.UpdateOptions
import com.mongodb.client.model.Updates
import com.mongodb.client.result.UpdateResult
import com.mongodb.kotlin.client.coroutine.MongoDatabase
import de.timbachmann.api.model.entity.Game
import de.timbachmann.api.model.request.GameUpdateRequest
import de.timbachmann.api.repository.interfaces.GameRepositoryInterface
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.flow.toList
import org.bson.BsonValue
import org.bson.conversions.Bson
import org.bson.types.ObjectId

/**
 * Repository class for handling database operations related to games.
 * Implements the {@link GameRepositoryInterface}.
 */
class GameRepository(private val mongoDatabase: MongoDatabase) : GameRepositoryInterface {

    companion object {
        /** The name of the game collection in MongoDB. */
        const val GAME_COLLECTION = "game"
    }

    /**
     * Inserts a new game into the database.
     *
     * @param game The game entity to insert.
     * @return The BSON ID of the inserted document or null if an error occurs.
     */
    override suspend fun insertOne(game: Game): BsonValue? {
        try {
            val result = mongoDatabase.getCollection<Game>(GAME_COLLECTION).insertOne(game)
            return result.insertedId
        } catch (e: MongoException) {
            System.err.println("Unable to insert due to an error: $e")
        }
        return null
    }

    /**
     * Deletes a game from the database by ID.
     *
     * @param objectId The ID of the game to delete.
     * @return The number of deleted documents (1 if successful, 0 if not found).
     */
    override suspend fun deleteById(objectId: ObjectId): Long {
        try {
            val result = mongoDatabase.getCollection<Game>(GAME_COLLECTION).deleteOne(Filters.eq("_id", objectId))
            return result.deletedCount
        } catch (e: MongoException) {
            System.err.println("Unable to delete due to an error: $e")
        }
        return 0
    }

    /**
     * Retrieves all games from the database.
     *
     * @return A list of all games.
     */
    override suspend fun getAll(): List<Game> =
        mongoDatabase.getCollection<Game>(GAME_COLLECTION).withDocumentClass<Game>()
            .find().toList()

    /**
     * Finds a game by its ID.
     *
     * @param objectId The ID of the game.
     * @return The game if found, otherwise null.
     */
    override suspend fun findById(objectId: ObjectId): Game? =
        mongoDatabase.getCollection<Game>(GAME_COLLECTION).withDocumentClass<Game>()
            .find(Filters.eq("_id", objectId)).firstOrNull()

    /**
     * Updates an existing game in the database.
     *
     * @param objectId The ID of the game to update.
     * @param game The updated game data.
     * @return An {@link UpdateResult} containing details of the update operation.
     */
    override suspend fun updateOne(objectId: ObjectId, gameUpdate: GameUpdateRequest): UpdateResult {
        val query = Filters.eq("_id", objectId)
        val updates = mutableListOf<Bson>()

        gameUpdate.gameState?.let { updates.add(Updates.set("gameState", it)) }
        gameUpdate.moves?.let { updates.add(Updates.set("moves", it)) }
        gameUpdate.white?.let { updates.add(Updates.set("white", it)) }
        gameUpdate.black?.let { updates.add(Updates.set("black", it)) }
        gameUpdate.checkers?.let { updates.add(Updates.set("checkers", it)) }
        gameUpdate.opponent?.let { updates.add(Updates.set("opponent", it)) }
        gameUpdate.opponentStrength?.let { updates.add(Updates.set("opponentStrength", it)) }
        gameUpdate.winner?.let { updates.add(Updates.set("winner", it)) }

        if (updates.isEmpty()) {
            throw IllegalArgumentException("No fields provided to update.")
        }

        val options = UpdateOptions().upsert(true)
        return mongoDatabase.getCollection<Game>(GAME_COLLECTION).updateOne(query, updates, options)
    }
}
