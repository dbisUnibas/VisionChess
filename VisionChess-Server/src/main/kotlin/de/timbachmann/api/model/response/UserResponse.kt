package de.timbachmann.api.model.response

/**
 * Data class representing the response for a user.
 *
 * @property id The unique identifier of the user.
 * @property email The email address of the user.
 * @property password The hashed password of the user.
 * @property lastLogin The timestamp of the user's last login.
 * @property activeSessions A list of active user sessions.
 * @property role The role assigned to the user (e.g., ADMIN, USER).
 */
data class UserResponse(
    val id: String,
    val email: String,
    val password: String,
    val lastLogin: String,
    val activeSessions: List<UserSessionResponse>,
    val role: String
)

/**
 * Data class representing a user session response.
 *
 * @property token The JWT token for the session.
 * @property CSRF The CSRF token associated with the session.
 * @property validTo The expiration date of the session.
 */
data class UserSessionResponse(
    val token: String,
    val CSRF: String,
    val validTo: String
)
