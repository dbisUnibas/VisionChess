package de.timbachmann.plugins

import io.ktor.serialization.gson.*
import io.ktor.server.application.*
import io.ktor.server.plugins.contentnegotiation.*

/**
 * Configures serialization for the Ktor application.
 * This function installs the ContentNegotiation plugin and sets up Gson as the serialization format.
 */
fun Application.configureSerialization() {
    install(ContentNegotiation) {
        gson{}
    }
}
