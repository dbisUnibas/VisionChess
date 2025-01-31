package de.timbachmann.api.model.response

/**
 * Data class representing the response for a successful login.
 *
 * @property token The JWT authentication token issued for the session.
 * @property user The user details associated with the session.
 */
data class LoginResponse(
    val token: String,
    val user: UserLoginResponse
)
