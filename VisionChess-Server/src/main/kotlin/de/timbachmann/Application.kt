package de.timbachmann

import de.timbachmann.plugins.*
import io.ktor.server.application.*
import io.ktor.server.netty.*

/**
 * Main function that starts the application using Ktor's Netty Engine.
 * It delegates execution to EngineMain, which reads the application settings from the configuration file.
 */
fun main(args: Array<String>): Unit = EngineMain.main(args)

/**
 * Extension function for the Application class.
 * This function is called when the Ktor application starts.
 * It initializes various configurations such as security, HTTP settings, monitoring, serialization, database, and routing.
 */
fun Application.module() {

    configureSecurity()      // Sets up authentication and authorization mechanisms
    configureHTTP()         // Configures HTTP settings such as headers, CORS, etc.
    configureMonitoring()   // Enables logging and monitoring for the application
    configureSerialization() // Configures content serialization (e.g., JSON, XML)
    configureDatabase()      // Sets up database connections and ORM settings
    configureRouting()       // Defines the application's API endpoints and routing
}