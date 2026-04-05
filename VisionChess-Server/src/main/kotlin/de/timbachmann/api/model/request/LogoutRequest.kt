package de.timbachmann.api.model.request

/**
 * Data class representing a request to log out a user.
 *
 * @property id The unique identifier of the user who is logging out.
 */
data class LogoutRequest(
    val id: String
)
