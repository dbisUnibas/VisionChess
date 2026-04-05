package de.timbachmann.plugins

import io.ktor.server.application.*
import io.ktor.server.plugins.callloging.*
import io.ktor.server.request.*
import org.slf4j.event.*

/**
 * Configures monitoring and logging for the Ktor application.
 * This function installs the CallLogging plugin to log incoming requests,
 * filtering only those that start with "/".
 */
fun Application.configureMonitoring() {
    install(CallLogging) {
        level = Level.INFO
        filter { call -> call.request.path().startsWith("/") }
    }
}
