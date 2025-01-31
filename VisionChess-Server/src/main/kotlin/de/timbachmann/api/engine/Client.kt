package de.timbachmann.api.engine

import de.timbachmann.api.model.entity.Side
import java.io.BufferedReader
import java.io.IOException
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.util.concurrent.CompletableFuture
import java.util.concurrent.CompletableFuture.supplyAsync
import java.util.concurrent.ExecutionException
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import java.util.function.Function
import java.util.function.Function.identity
import java.util.function.Predicate

/**
 * Client class for interacting with the Stockfish chess engine.
 * Provides methods to initialize the engine, set positions, make moves, and retrieve analysis results.
 */
class Client {
    private var process: Process? = null
    private var reader: BufferedReader? = null
    private var writer: OutputStreamWriter? = null
    private val stockfishPath = "./stockfish/stockfish"

    /**
     * Initializes the Stockfish process and sets up input/output streams.
     */
    init {
        val pb = ProcessBuilder(stockfishPath)
        try {
            val p = pb.start()
            this.process = p
            this.reader = BufferedReader(InputStreamReader(p.inputStream))
            this.writer = OutputStreamWriter(p.outputStream)
        } catch (e: IOException) {
            e.printStackTrace()
        }
    }

    /**
     * Closes the Stockfish process and input/output streams.
     */
    fun close() {
        if (this.process?.isAlive == true) {
            this.process!!.destroy()
        }
        try {
            reader?.close()
            writer?.close()
        } catch (e: IOException) {
            e.printStackTrace()
        }
    }

    /**
     * Initializes the UCI (Universal Chess Interface) for communication with Stockfish.
     */
    fun initUci() {
        try {
            command("uci", identity(), { s -> s?.startsWith("uciok") == true }, 2000L)
        } catch (e: IOException) {
            e.printStackTrace()
        }
    }

    /**
     * Sets the position on the chessboard using FEN notation.
     *
     * @param fen The FEN string representing the game position.
     * @return `true` if the position was successfully set, `false` otherwise.
     */
    fun setPosition(fen: String): Boolean {
        if (!isFenSyntaxValid(fen)) {
            return false
        }
        try {
            val commandStr = if (fen == "startpos") "position startpos" else "position fen $fen"
            command(commandStr, identity(), { s -> s?.startsWith("readyok") == true }, 2000L)
            return true
        } catch (e: IOException) {
            e.printStackTrace()
        }
        return false
    }

    /**
     * Makes a move in the current game state.
     *
     * @param move The move to be played in UCI format.
     * @param currentPosition The current position in FEN notation (default: "startpos").
     * @return `true` if the move is valid and executed, `false` otherwise.
     */
    fun move(move: String, currentPosition: String = "startpos"): Boolean {
        try {
            if (isFenSyntaxValid(currentPosition) && isValidMove(move, currentPosition)) {
                val commandStr = if (currentPosition == "startpos") {
                    "position startpos moves $move"
                } else {
                    "position fen $currentPosition moves $move"
                }
                command(commandStr, identity(), { s -> s?.startsWith("readyok") == true }, 2000L)
                return true
            }
            return false
        } catch (e: IOException) {
            e.printStackTrace()
        }
        return false
    }

    /**
     * Retrieves the current position from Stockfish.
     *
     * @return The FEN string representing the current board state, or `null` if retrieval fails.
     */
    fun getCurrentPosition(): String? {
        try {
            val currentPosition: String = command(
                "d",
                { lines -> lines.stream().filter { s -> s.startsWith("Fen:") }.findFirst().get() },
                { line -> line?.startsWith("Checkers:") == true },
                5000L
            ).split(" ").drop(1).joinToString(" ")

            return currentPosition
        } catch (e: IOException) {
            e.printStackTrace()
        }
        return null
    }

    /**
     * Retrieves the best move suggested by Stockfish.
     *
     * @param movetime The amount of time (in milliseconds) Stockfish should spend calculating the best move.
     * @return The best move as a string, or `null` if retrieval fails.
     */
    fun getCurrentBestMove(movetime: Int = 3000): String? {
        try {
            val bestMove: String = command(
                "go movetime $movetime",
                { lines -> lines.stream().filter { s -> s.startsWith("bestmove") }.findFirst().get() },
                { line -> line?.startsWith("bestmove") == true },
                5000L
            ).split(" ")[1]

            return bestMove
        } catch (e: IOException) {
            e.printStackTrace()
        }
        return null
    }

    /**
     * Checks whether a given move is valid for the current board position.
     *
     * @param move The move to validate.
     * @param currentPosition The current position in FEN notation.
     * @return `true` if the move is valid, `false` otherwise.
     */
    private fun isValidMove(move: String, currentPosition: String): Boolean {
        try {
            setPosition(currentPosition)
            val validMove: String = command(
                "go depth 1 searchmoves $move",
                { lines -> lines.stream().filter { s -> s.startsWith("bestmove") }.findFirst().get() },
                { line -> line?.startsWith("bestmove") == true },
                5000L
            ).split(" ")[1]
            return validMove == move
        } catch (e: IOException) {
            e.printStackTrace()
        }
        return false
    }

    /**
     * Retrieves the side to move from a given FEN string.
     *
     * @param fen The FEN string representing the game position.
     * @return The corresponding {@link Side} (`WHITE` or `BLACK`), or `null` if FEN is invalid.
     */
    fun getSideToMove(fen: String): Side? {
        return if (fen == "startpos") Side.WHITE else getSideToMoveFromFen(fen)
    }

    /**
     * Sends a command to Stockfish and processes the response.
     *
     * @param cmd The command to send.
     * @param commandProcessor A function to process the output lines.
     * @param breakCondition A condition to determine when to stop reading output.
     * @param timeout The time limit for execution (in milliseconds).
     * @return The processed response.
     * @throws InterruptedException If the execution is interrupted.
     * @throws ExecutionException If an execution error occurs.
     * @throws TimeoutException If the command times out.
     */
    @Throws(InterruptedException::class, ExecutionException::class, TimeoutException::class)
    fun <T> command(
        cmd: String,
        commandProcessor: Function<MutableList<String>, T>,
        breakCondition: Predicate<String?>,
        timeout: Long
    ): T {
        val command: CompletableFuture<T> = supplyAsync {
            val output: MutableList<String> = ArrayList()
            try {
                writer?.flush()
                writer?.write(cmd + "\n")
                writer?.write("isready\n")
                writer?.flush()
                var line = ""
                while ((reader?.readLine().also {
                        if (it != null) {
                            line = it
                        }
                    }) != null) {
                    if (line.contains("Unknown command") || line.contains("Unexpected token")) {
                        throw RuntimeException("Error from Stockfish: $line")
                    }
                    output.add(line)
                    if (breakCondition.test(line)) break
                }
            } catch (e: IOException) {
                e.printStackTrace()
            }
            commandProcessor.apply(output)
        }

        return command[timeout, TimeUnit.MILLISECONDS]
    }
}
