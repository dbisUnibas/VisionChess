package de.timbachmann.api.repository.interfaces

import com.auth0.jwt.interfaces.DecodedJWT
import de.timbachmann.api.model.entity.User
import org.bson.BsonValue
import org.bson.types.ObjectId

/**
 * Interface defining the repository operations for the {@link User} entity.
 * Provides methods for user authentication, password management, and database operations.
 */
interface UserRepositoryInterface {

    /**
     * Creates a JWT token for the given user.
     *
     * @param userId The ID of the user.
     * @param email The email of the user.
     * @return A JWT token string or null if creation fails.
     */
    suspend fun createJwtToken(userId: String, email: String): String?

    /**
     * Decodes a given JWT token.
     *
     * @param token The JWT token to decode.
     * @return A {@link DecodedJWT} object or null if decoding fails.
     */
    suspend fun decodeJwtToken(token: String): DecodedJWT?

    /**
     * Inserts a new user into the database.
     *
     * @param user The user entity to insert.
     * @return The BSON ID of the inserted document or null if insertion fails.
     */
    suspend fun insertOne(user: User): BsonValue?

    /**
     * Deletes a user from the database by ID.
     *
     * @param objectId The ID of the user to delete.
     * @return The number of deleted documents (1 if successful, 0 if not found).
     */
    suspend fun deleteById(objectId: ObjectId): Long

    /**
     * Finds a user by their email.
     *
     * @param email The email of the user.
     * @return The user if found, otherwise null.
     */
    suspend fun findByEmail(email: String): User?

    /**
     * Finds a user by their ID.
     *
     * @param id The ID of the user.
     * @return The user if found, otherwise null.
     */
    suspend fun findById(id: ObjectId): User?

    /**
     * Checks if the provided password matches the stored hash.
     *
     * @param password The raw password input.
     * @param hash The hashed password stored in the database.
     * @return True if the password matches, false otherwise.
     */
    suspend fun checkPassword(password: String, hash: String): Boolean

    /**
     * Hashes a plain text password using bcrypt.
     *
     * @param password The raw password to hash.
     * @return The hashed password.
     */
    suspend fun hashPassword(password: String): String

    /**
     * Retrieves all users from the database.
     *
     * @return A list of all users.
     */
    suspend fun getAll(): List<User>

    /**
     * Updates an existing user in the database.
     *
     * @param objectId The ID of the user to update.
     * @param user The updated user data.
     * @return The number of modified documents (1 if successful, 0 if no changes).
     */
    suspend fun updateOne(objectId: ObjectId, user: User): Long
}
