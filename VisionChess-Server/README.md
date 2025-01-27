# VisionChess-Server

## Overview
VisionChess-Server is a Kotlin-based backend application designed to communicate with a chess engine supporting UCI (Universal Chess Interface) communication. The server provides a `Game` entity for managing chess games and offers suggestions for the best moves using the chess engine.

## Features
- **Chess engine integration**: Communicates with a UCI-compatible chess engine for move suggestions.
- **Game management**: Maintains the state of chess games through the `Game` entity.
- **API for move suggestions**: Offers endpoints to query the best moves from the current game state.
- **Modular architecture**: Separation of concerns with plugins, routes, and repositories.
- **OpenAPI integration**: API documentation included in `src/main/resources/openapi/documentation.yaml`.
- **Security and monitoring**: Security and monitoring modules for a robust backend.

## Project Structure
```
├── build.gradle.kts         # Gradle build script
├── settings.gradle.kts      # Gradle settings
├── src
│   ├── main
│   │   ├── kotlin
│   │   │   └── de.timbachmann
│   │   │       ├── Application.kt          # Application entry point
│   │   │       ├── plugins                 # Plugins for HTTP, routing, serialization, etc.
│   │   │       ├── api
│   │   │       │   ├── routes             # API routes (e.g., GameRoutes, UserRoutes)
│   │   │       │   ├── model              # Data models (entities, requests, responses)
│   │   │       │   ├── repository         # Repositories and interfaces for persistence
│   │   │       │   ├── engine             # Utility and client logic for UCI communication
│   │   │       └── ...
│   │   ├── resources
│   │       ├── application.conf          # Configuration file
│   │       ├── logback.xml               # Logging configuration
│   │       └── openapi
│   │           └── documentation.yaml    # OpenAPI documentation
```

## Getting Started

### Prerequisites
- [JDK 17+](https://adoptopenjdk.net/)
- [Gradle](https://gradle.org/install/)
- UCI-compatible chess engine (e.g., [Stockfish](https://stockfishchess.org/))

### Installation
1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd VisionChess-Server
   ```
2. Build the project:
   ```bash
   ./gradlew build
   ```
3. Run the application:
   ```bash
   ./gradlew run
   ```

### Configuration
Update the `application.conf` file in `src/main/resources` to configure your application (e.g., database connections, chess engine path, environment variables).

### API Documentation
The OpenAPI documentation is available at `src/main/resources/openapi/documentation.yaml`. Use tools like Swagger UI or Postman to interact with the API.

## Key Files
- **`Application.kt`**: Main entry point for the application.
- **`plugins`**: Handles features like routing, security, and serialization.
- **`routes`**: Defines API endpoints (e.g., `GameRoutes.kt`, `UserRoutes.kt`).
- **`engine`**: Manages communication with the UCI-compatible chess engine.
- **`repositories`**: Manages database interactions and persistence logic.
- **`application.conf`**: Contains application configuration.

## Contributing
1. Fork the repository.
2. Create a new feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. Commit your changes:
   ```bash
   git commit -m "Add your message here"
   ```
4. Push to your branch:
   ```bash
   git push origin feature/your-feature-name
   ```
5. Open a pull request.

## License
This project is licensed under the MIT License. See the `LICENSE` file for more details.

---

For any questions or issues, please contact the maintainer.
