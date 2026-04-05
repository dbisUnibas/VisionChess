package de.timbachmann.api.repository.interfaces

import com.mongodb.client.result.UpdateResult
import de.timbachmann.api.model.entity.Game
import de.timbachmann.api.model.request.GameUpdateRequest
import org.bson.BsonValue
import org.bson.types.ObjectId

/**
 * Interface defining the repository operations for the {@link Game} entity.
 * Provides methods for inserting, updating, retrieving, and deleting games in the database.
 */
interface GameRepositoryInterface {

    /**
     * Inserts a new game into the database.
     *
     * @param game The game entity to insert.
     * @return The BSON ID of the inserted document or null if insertion fails.
     */
    suspend fun insertOne(game: Game): BsonValue?

    /**
     * Deletes a game from the database by its ID.
     *
     * @param objectId The ID of the game to delete.
     * @return The number of deleted documents (1 if successful, 0 if not found).
     */
    suspend fun deleteById(objectId: ObjectId): Long

    /**
     * Finds a game by its ID.
     *
     * @param objectId The ID of the game.
     * @return The game if found, otherwise null.
     */
    suspend fun findById(objectId: ObjectId): Game?

    /**
     * Retrieves all games from the database.
     *
     * @return A list of all games.
     */
    suspend fun getAll(): List<Game>

    /**
     * Updates an existing game in the database.
     *
     * @param objectId The ID of the game to update.
     * @param game The updated game data.
     * @return An {@link UpdateResult} containing details of the update operation.
     */
    suspend fun updateOne(objectId: ObjectId, gameUpdate: GameUpdateRequest): UpdateResult
}
