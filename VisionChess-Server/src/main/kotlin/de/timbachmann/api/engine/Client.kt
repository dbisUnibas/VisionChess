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


class Client {
    private var process: Process? = null
    private var reader: BufferedReader? = null
    private var writer: OutputStreamWriter? = null
    private val stockfishPath = "./stockfish/stockfish"

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

    fun close() {
        if (this.process?.isAlive == true) {
            this.process!!.destroy();
        }
        try {
            reader?.close();
            writer?.close();
        } catch (e: IOException) {
            e.printStackTrace();
        }
    }

    fun initUci() {
        try {
            command("uci", identity(), { s -> s?.startsWith("uciok") == true }, 2000L)
        } catch (e: IOException) {
            e.printStackTrace()
        }
    }

    fun setPosition(fen: String): Boolean {
        if(!isFenSyntaxValid(fen)) {
            return false;
        }
        try {
            command("position fen $fen", identity(), { s -> s?.startsWith("readyok") == true }, 2000L)
            return true;
        } catch (e: IOException) {
            e.printStackTrace()
        }
        return false;
    }

    fun move(move: String, currentPosition: String = "startpos"): Boolean {
        try {
            if (isFenSyntaxValid(currentPosition) && isValidMove(move)) {
                if (currentPosition == "startpos") {
                    command("position startpos moves $move", identity(), { s -> s?.startsWith("readyok") == true }, 2000L)
                    return true;
                } else {
                    command("position fen $currentPosition moves $move", identity(), { s -> s?.startsWith("readyok") == true }, 2000L)
                    return true;
                }
            }
            return false;
        } catch (e: IOException) {
            e.printStackTrace()
        }
        return false;
    }

    fun getCurrentPosition(): String? {
        try {
            val currentPosition: String = command(
                "d",
                { lines -> lines.stream().filter { s -> s.startsWith("Fen:") }.findFirst().get() },
                { line -> line?.startsWith("Checkers:") == true },
                5000L
            ).split(" ").drop(1).joinToString(" ")

            return currentPosition;
        } catch (e: IOException) {
            e.printStackTrace()
        }
        return null;
    }

    fun getCurrentBestMove(movetime: Int = 3000): String? {
        try {
            val bestMove: String = command(
                "go movetime $movetime",
                { lines -> lines.stream().filter { s -> s.startsWith("bestmove") }.findFirst().get() },
                { line -> line?.startsWith("bestmove") == true },
                5000L
            ).split(" ")[1]

            return bestMove;
        } catch (e: IOException) {
            e.printStackTrace()
        }
        return null;
    }

    private fun isValidMove(move: String): Boolean {
        try {
            val validMove: String = command(
                "go depth 1 searchmoves $move",
                { lines -> lines.stream().filter { s -> s.startsWith("bestmove") }.findFirst().get() },
                { line -> line?.startsWith("bestmove") == true },
                5000L
            ).split(" ")[1]
            return validMove === move

        } catch (e: IOException) {
            e.printStackTrace()
        }
        return false
    }

    fun getSideToMove(fen: String): Side? {
        return getSideToMoveFromFen(fen);
    }

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
                    if (line.contains("Unknown command")) {
                        throw RuntimeException(line)
                    }
                    if (line.contains("Unexpected token")) {
                        throw RuntimeException("Unexpected token: $line")
                    }
                    output.add(line)
                    if (breakCondition.test(line)) {
                        break
                    }
                }
            } catch (e: IOException) {
                e.printStackTrace()
            }
            commandProcessor.apply(output)
        }

        return command[timeout, TimeUnit.MILLISECONDS]
    }
}