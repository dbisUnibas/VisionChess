package de.timbachmann.api.model.request

import de.timbachmann.api.model.entity.User
import de.timbachmann.api.model.entity.UserSession
import org.bson.types.ObjectId
import java.util.*

/**
 * Data class representing the request to create or update a user.
 *
 * @property email The email address of the user.
 * @property password The raw password of the user.
 * @property lastLogin The timestamp of the user's last login.
 * @property activeSessions A list of active user sessions.
 * @property role The role assigned to the user (e.g., ADMIN, USER).
 */
data class UserRequest(
    val email: String,
    val password: String,
    val lastLogin: String,
    val activeSessions: List<UserSession>,
    val role: String
) {

    /**
     * Converts the `UserRequest` object to a `User` entity for database storage.
     *
     * @return A new {@link User} object with a generated ID and default values.
     */
    fun toUserObject(): User {
        return User(
            id = ObjectId(),
            email = email,
            password = password,
            lastLogin = Date(),
            activeSessions = listOf(),
            role = role
        )
    }
}
