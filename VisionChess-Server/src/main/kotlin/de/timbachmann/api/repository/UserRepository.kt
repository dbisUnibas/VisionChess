package de.timbachmann.api.repository

import com.auth0.jwt.JWT
import com.auth0.jwt.algorithms.Algorithm
import com.auth0.jwt.interfaces.DecodedJWT
import com.mongodb.MongoException
import com.mongodb.client.model.Filters
import com.mongodb.client.model.UpdateOptions
import com.mongodb.client.model.Updates
import com.mongodb.kotlin.client.coroutine.MongoDatabase
import de.timbachmann.api.model.entity.User
import de.timbachmann.api.repository.interfaces.UserRepositoryInterface
import io.ktor.server.application.*
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.flow.toList
import org.bson.BsonValue
import org.bson.types.ObjectId
import org.mindrot.jbcrypt.BCrypt
import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.*

/**
 * Repository class for handling database operations related to users.
 * Implements the {@link UserRepositoryInterface}.
 */
class UserRepository(private val mongoDatabase: MongoDatabase, private val application: Application) : UserRepositoryInterface {

    companion object {
        /** The name of the user collection in MongoDB. */
        const val USER_COLLECTION = "user"
    }

    /**
     * Creates a JWT token for the given user.
     *
     * @param userId The ID of the user.
     * @param email The email of the user.
     * @return A JWT token string or null if creation fails.
     */
    override suspend fun createJwtToken(userId: String, email: String): String? {
        return JWT.create()
            .withIssuer(application.environment.config.property("ktor.jwt.issuer").getString())
            .withClaim("email", email)
            .withClaim("id", userId)
            .withExpiresAt(Date.from(Instant.now().plus(7, ChronoUnit.DAYS)))
            .sign(Algorithm.HMAC256(application.environment.config.property("ktor.jwt.secret").getString()))
    }

    /**
     * Decodes a given JWT token.
     *
     * @param token The JWT token to decode.
     * @return A {@link DecodedJWT} object or null if decoding fails.
     */
    override suspend fun decodeJwtToken(token: String): DecodedJWT? {
        return JWT.decode(token)
    }

    /**
     * Inserts a new user into the database.
     *
     * @param user The user entity to insert.
     * @return The BSON ID of the inserted document or null if an error occurs.
     */
    override suspend fun insertOne(user: User): BsonValue? {
        try {
            val result = mongoDatabase.getCollection<User>(USER_COLLECTION).insertOne(user)
            return result.insertedId
        } catch (e: MongoException) {
            System.err.println("Unable to insert due to an error: $e")
        }
        return null
    }

    /**
     * Deletes a user from the database by ID.
     *
     * @param objectId The ID of the user to delete.
     * @return The number of deleted documents (1 if successful, 0 if not found).
     */
    override suspend fun deleteById(objectId: ObjectId): Long {
        try {
            val result = mongoDatabase.getCollection<User>(USER_COLLECTION).deleteOne(Filters.eq("_id", objectId))
            return result.deletedCount
        } catch (e: MongoException) {
            System.err.println("Unable to delete due to an error: $e")
        }
        return 0
    }

    /**
     * Retrieves all users from the database.
     *
     * @return A list of all users.
     */
    override suspend fun getAll(): List<User> =
        mongoDatabase.getCollection<User>(USER_COLLECTION).withDocumentClass<User>()
            .find().toList()

    /**
     * Finds a user by their email.
     *
     * @param email The email of the user.
     * @return The user if found, otherwise null.
     */
    override suspend fun findByEmail(email: String): User? =
        mongoDatabase.getCollection<User>(USER_COLLECTION).withDocumentClass<User>()
            .find(Filters.eq("email", email)).firstOrNull()

    /**
     * Finds a user by their ID.
     *
     * @param id The ID of the user.
     * @return The user if found, otherwise null.
     */
    override suspend fun findById(id: ObjectId): User? =
        mongoDatabase.getCollection<User>(USER_COLLECTION).withDocumentClass<User>()
            .find(Filters.eq("_id", id)).firstOrNull()

    /**
     * Checks if the provided password matches the stored hash.
     *
     * @param password The raw password input.
     * @param hash The hashed password stored in the database.
     * @return True if the password matches, false otherwise.
     */
    override suspend fun checkPassword(password: String, hash: String): Boolean = BCrypt.checkpw(password, hash)

    /**
     * Hashes a plain text password using bcrypt.
     *
     * @param password The raw password to hash.
     * @return The hashed password.
     */
    override suspend fun hashPassword(password: String): String = BCrypt.hashpw(password, BCrypt.gensalt())

    /**
     * Updates an existing user in the database.
     *
     * @param objectId The ID of the user to update.
     * @param user The updated user data.
     * @return The number of modified documents (1 if successful, 0 if no changes).
     */
    override suspend fun updateOne(objectId: ObjectId, user: User): Long {
        try {
            val query = Filters.eq("_id", objectId)
            val updates = Updates.combine(
                Updates.set(User::email.name, user.email),
                Updates.set(User::password.name, user.password),
                Updates.set(User::lastLogin.name, user.lastLogin),
                Updates.set(User::activeSessions.name, user.activeSessions),
                Updates.set(User::role.name, user.role)
            )
            val options = UpdateOptions().upsert(true)
            val result = mongoDatabase.getCollection<User>(USER_COLLECTION).updateOne(query, updates, options)

            return result.modifiedCount
        } catch (e: MongoException) {
            System.err.println("Unable to update due to an error: $e")
        }
        return 0
    }
}
