package de.timbachmann.api.repository

import com.mongodb.MongoException
import com.mongodb.client.model.Filters
import com.mongodb.client.model.UpdateOptions
import com.mongodb.client.model.Updates
import com.mongodb.client.result.UpdateResult
import com.mongodb.kotlin.client.coroutine.MongoDatabase
import de.timbachmann.api.model.entity.Game
import de.timbachmann.api.repository.interfaces.GameRepositoryInterface
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.flow.toList
import org.bson.BsonValue
import org.bson.types.ObjectId

class GameRepository(private val mongoDatabase: MongoDatabase) : GameRepositoryInterface {

    companion object {
        const val GAME_COLLECTION = "game"
    }

    override suspend fun insertOne(game: Game): BsonValue? {
        try {
            val result = mongoDatabase.getCollection<Game>(GAME_COLLECTION).insertOne(
                game
            )
            return result.insertedId
        } catch (e: MongoException) {
            System.err.println("Unable to insert due to an error: $e")
        }
        return null
    }

    override suspend fun deleteById(objectId: ObjectId): Long {
        try {
            val result = mongoDatabase.getCollection<Game>(GAME_COLLECTION).deleteOne(Filters.eq("_id", objectId))
            return result.deletedCount
        } catch (e: MongoException) {
            System.err.println("Unable to delete due to an error: $e")
        }
        return 0
    }

    override suspend fun getAll(): List<Game> =
        mongoDatabase.getCollection<Game>(GAME_COLLECTION).withDocumentClass<Game>()
            .find().toList()

    override suspend fun findById(objectId: ObjectId): Game? =
        mongoDatabase.getCollection<Game>(GAME_COLLECTION).withDocumentClass<Game>()
            .find(Filters.eq("_id", objectId)).firstOrNull()

    override suspend fun updateOne(objectId: ObjectId, game: Game): UpdateResult {
        val query = Filters.eq("_id", objectId)
        val updates = Updates.combine(
            Updates.set(Game::gameState.name, game.gameState),
            Updates.set(Game::moves.name, game.moves),
            Updates.set(Game::white.name, game.white),
            Updates.set(Game::black.name, game.black),
            Updates.set(Game::opponent.name, game.opponent),
            Updates.set(Game::winner.name, game.winner)
        )
        val options = UpdateOptions().upsert(true)
        val result =
            mongoDatabase.getCollection<Game>(GAME_COLLECTION)
                .updateOne(query, updates, options)

        return result
    }
}