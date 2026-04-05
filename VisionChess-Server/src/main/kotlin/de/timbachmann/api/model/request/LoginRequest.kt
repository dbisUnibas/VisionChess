package de.timbachmann.api.model.request

/**
 * Data class representing a request to log in a user.
 *
 * @property email The email address of the user.
 * @property password The user's password.
 */
data class LoginRequest(
    val email: String,
    val password: String,
)
