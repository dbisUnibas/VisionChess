package de.timbachmann.api.model.entity

import de.timbachmann.api.model.response.UserResponse
import de.timbachmann.api.model.response.UserSessionResponse
import org.bson.codecs.pojo.annotations.BsonId
import org.bson.types.ObjectId
import java.util.*

/**
 * Data class representing a user entity stored in the database.
 *
 * @property id The unique identifier of the user.
 * @property email The email address of the user.
 * @property password The hashed password of the user.
 * @property lastLogin The timestamp of the user's last login.
 * @property activeSessions A list of active user sessions.
 * @property role The role assigned to the user (e.g., ADMIN, USER).
 */
data class User(
    @BsonId
    val id: ObjectId,
    val email: String,
    val password: String,
    val lastLogin: Date,
    val activeSessions: List<UserSession>,
    val role: String
) {
    /**
     * Converts the `User` entity to a `UserResponse` object for API responses.
     *
     * @return A `UserResponse` representation of this `User` entity.
     */
    fun toResponse() = UserResponse(
        id = id.toString(),
        email = email,
        password = password,
        lastLogin = lastLogin.toString(),
        activeSessions = activeSessions.map { it.toResponse() },
        role = role
    )
}

/**
 * Data class representing an active user session.
 *
 * @property token The JWT token for the session.
 * @property CSRF The CSRF token associated with the session.
 * @property validTo The expiration date of the session.
 */
data class UserSession(
    val token: String,
    val CSRF: String,
    val validTo: Date
) {
    /**
     * Converts the `UserSession` entity to a `UserSessionResponse` object for API responses.
     *
     * @return A `UserSessionResponse` representation of this session.
     */
    fun toResponse() = UserSessionResponse(
        token = token,
        CSRF = CSRF,
        validTo = validTo.toString(),
    )
}
