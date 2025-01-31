package de.timbachmann.api.model.response

/**
 * Data class representing the response for a user login.
 *
 * @property id The unique identifier of the user.
 * @property email The email address of the user.
 * @property CSRF The CSRF token associated with the session.
 * @property role The role assigned to the user (e.g., ADMIN, USER).
 */
data class UserLoginResponse(
    val id: String,
    val email: String,
    val CSRF: String,
    val role: String,
)
