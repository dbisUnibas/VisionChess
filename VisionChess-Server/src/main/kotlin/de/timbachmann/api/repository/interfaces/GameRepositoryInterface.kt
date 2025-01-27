package de.timbachmann.api.repository.interfaces

import com.mongodb.client.result.UpdateResult
import de.timbachmann.api.model.entity.Game
import org.bson.BsonValue
import org.bson.types.ObjectId

interface GameRepositoryInterface {
    suspend fun insertOne(game: Game): BsonValue?
    suspend fun deleteById(objectId: ObjectId): Long
    suspend fun findById(objectId: ObjectId): Game?
    suspend fun getAll(): List<Game>
    suspend fun updateOne(objectId: ObjectId, game: Game): UpdateResult
}