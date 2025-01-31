package de.timbachmann.plugins

import de.timbachmann.api.routes.gameRouting
import de.timbachmann.api.routes.userRouting
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import io.ktor.server.plugins.statuspages.*

/**
 * Configures routing for the Ktor application.
 * This function sets up global exception handling, default route redirection,
 * and includes game and user-related routes.
 */
fun Application.configureRouting() {
    install(StatusPages) {
        exception<Throwable> { call, cause ->
            call.respondText(text = "500: $cause", status = HttpStatusCode.InternalServerError)
        }
    }
    routing {
        get("/") {
            call.respondRedirect("/swagger-ui")
        }
        gameRouting()
        userRouting()
    }
}
