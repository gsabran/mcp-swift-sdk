import Foundation
import JSONRPC
import MCPInterface
import OSLog

private let logger = Logger(
  subsystem: Bundle.main.bundleIdentifier.map { "\($0).jsonrpc" } ?? "com.app.jsonrpc",
  category: "jsonrpc")

// MARK: - JSONRPCSetupError

public enum JSONRPCSetupError: Error {
  case missingStandardIO
  case standardIOConnectionError(_ message: String)
  case couldNotLocateExecutable(executable: String, error: String?)
}

// MARK: LocalizedError

extension JSONRPCSetupError: LocalizedError {

  public var errorDescription: String? {
    switch self {
    case .missingStandardIO:
      "Missing standard IO"
    case .couldNotLocateExecutable(let executable, let error):
      "Could not locate executable \(executable) \(error ?? "")".trimmingCharacters(in: .whitespaces)
    case .standardIOConnectionError(let message):
      "Could not connect to stdio: \(message)".trimmingCharacters(in: .whitespaces)
    }
  }

  public var recoverySuggestion: String? {
    switch self {
    case .missingStandardIO:
      "Make sure that the Process that is passed as an argument has stdin, stdout and stderr set as a Pipe."
    case .couldNotLocateExecutable:
      "Check that the executable is findable given the PATH environment variable. If needed, pass the right environment to the process."
    case .standardIOConnectionError:
      nil
    }
  }
}

extension Transport {

  #if os(macOS)
  /// Creates a new `Transport` by launching the given executable with the specified arguments and attaching to its standard IO.
  /// This functionality is only available on macOS.
  public static func stdioProcess(
    _ executable: String,
    args: [String] = [],
    cwd: String? = nil,
    env: [String: String]? = nil,
    verbose: Bool = false)
    throws -> Transport
  {
    if verbose {
      let command = "\(executable) \(args.joined(separator: " "))"
      logger.log("Running ↪ \(command)")
    }

    // Create the process
    func path(for executable: String, env: [String: String]?) -> String? {
      guard !executable.contains("/") else {
        return executable
      }
      do {
        let path = try locate(executable: executable, env: env)
        return path.isEmpty ? nil : path
      } catch {
        // Most likely an error because we could not locate the executable
        return nil
      }
    }

    let process = Process()
    // In MacOS, zsh is the default since macOS Catalina 10.15.7. We can safely assume it is available.
    process.launchPath = "/bin/zsh"

    if let executable = path(for: executable, env: env) {
      // If executable is found directly, use user-provided env or current process env
      process.environment = env ?? ProcessInfo.processInfo.environment
      let command = "\(executable) \(args.joined(separator: " "))"
      process.arguments = ["-c"] + [command]
    } else {
      // If we cannot locate the executable, try loading the default environment for zsh
      process.environment = try loadZshEnvironment(userEnv: env)
      let command = "\(executable) \(args.joined(separator: " "))"
      process.arguments = ["-c"] + [command]
    }

    // Working directory
    if let cwd {
      process.currentDirectoryPath = cwd
    }

    // Input/output
    let stdin = Pipe()
    let stdout = Pipe()
    let stderr = Pipe()
    process.standardInput = stdin
    process.standardOutput = stdout
    process.standardError = stderr

    return try stdioProcess(unlaunchedProcess: process, verbose: verbose)
  }

  /// Creates a new `Transport` by launching the given process and attaching to its standard IO.
  /// This functionality is only available on macOS.
  public static func stdioProcess(
    unlaunchedProcess process: Process,
    verbose: Bool = false)
    throws -> Transport
  {
    guard
      let stdin = process.standardInput as? Pipe,
      let stdout = process.standardOutput as? Pipe,
      let stderr = process.standardError as? Pipe
    else {
      throw JSONRPCSetupError.missingStandardIO
    }

    // Run the process
    var stdoutData = Data()
    var stderrData = Data()
    let outStream: AsyncStream<Data>
    if verbose {
      // As we are both reading stdout here in this function, and want to make the stream readable to the caller,
      // we read the data from the process's stdout, process it and then re-yield it to the caller to a new stream.
      // This is because an AsyncStream can have only one reader.
      var outContinuation: AsyncStream<Data>.Continuation?
      outStream = AsyncStream<Data> { continuation in
        outContinuation = continuation
      }

      Task {
        for await data in stdout.fileHandleForReading.dataStream.jsonStream {
          stdoutData.append(data)
          outContinuation?.yield(data)

          logger.log("Received data:\n\(String(data: data, encoding: .utf8) ?? "nil")")
        }
        outContinuation?.finish()
      }

      if stdout.fileHandleForReading.fileDescriptor != stderr.fileHandleForReading.fileDescriptor {
        Task {
          for await data in stderr.fileHandleForReading.dataStream {
            logger.log("Received error:\n\(String(data: data, encoding: .utf8) ?? "nil")")
            stderrData.append(data)
          }
        }
      }
    } else {
      // If we are not in verbose mode, we are not reading from stdout internally, so we can just return the stream directly.
      outStream = stdout.fileHandleForReading.dataStream.jsonStream
    }

    // Ensures that the process is terminated when the Transport is de-referenced.
    let lifetime = Lifetime {
      if process.isRunning {
        process.terminate()
      }
    }

    if process.terminationHandler == nil {
      process.terminationHandler = { task in
        if verbose {
          logger
            .log(
              "Process \(process.processIdentifier) terminated with termination status \(task.terminationStatus)\(stdoutData.toLog(withTitle: "stdout"))\(stderrData.toLog(withTitle: "stderr"))")
        }
      }
    }

    do {
      try process.launchThrowably()
    } catch {
      assertionFailure("Unexpected error: \(error)")
      throw error
    }

    let writeHandler: Transport.WriteHandler = { [lifetime] data in
      _ = lifetime
      if verbose {
        logger.log("Sending data:\n\(String(data: data, encoding: .utf8) ?? "nil")")
      }

      stdin.fileHandleForWriting.write(data)
      // Send \n to flush the buffer
      stdin.fileHandleForWriting.write(Data("\n".utf8))
    }

    return Transport(writeHandler: writeHandler, dataSequence: outStream)
  }

  /// Finds the full path to the executable using the `which` command.
  /// This functionality is only available on macOS.
  private static func locate(executable: String, env: [String: String]? = nil) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    process.arguments = [executable]

    if let env {
      process.environment = env
    }

    guard let executablePath = try getProcessStdout(process: process), !executablePath.isEmpty
    else {
      throw JSONRPCSetupError.couldNotLocateExecutable(executable: executable, error: "")
    }
    return executablePath
  }

  /// Loads the zsh environment variables.
  /// This functionality is only available on macOS.
  private static func loadZshEnvironment(userEnv: [String: String]? = nil) throws -> [String: String] {
    // Load shell environment as base
    let shellProcess = Process()
    shellProcess.executableURL = URL(fileURLWithPath: "/bin/zsh")

    // Set process environment - either use userEnv if it exists and isn't empty, or use system environment
    if let env = userEnv, !env.isEmpty {
      shellProcess.environment = env
    } else {
      shellProcess.environment = ProcessInfo.processInfo.environment
    }

    shellProcess.arguments = ["-ilc", "printenv"]

    let outputPipe = Pipe()
    shellProcess.standardOutput = outputPipe
    shellProcess.standardError = Pipe()

    try shellProcess.run()
    shellProcess.waitUntilExit()

    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
    guard let outputString = String(data: data, encoding: .utf8) else {
      logger.error("Failed to read environment from shell.")
      return ProcessInfo.processInfo.environment
    }

    // Parse shell environment
    return outputString
      .split(separator: "\n")
      .reduce(into: [String: String]()) { result, line in
        let components = line.split(separator: "=", maxSplits: 1)
        guard components.count == 2 else { return }
        result[String(components[0])] = String(components[1])
      }
  }

  /// Gets the standard output from a process.
  /// This functionality is only available on macOS.
  private static func getProcessStdout(process: Process) throws -> String? {
    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr

    let group = DispatchGroup()
    var stdoutData = Data()
    var stderrData = Data()

    // From https://github.com/kareman/SwiftShell/blob/99680b2efc7c7dbcace1da0b3979d266f02e213c/Sources/SwiftShell/Command.swift#L140-L163
    do {
      try process.launchThrowably()

      if stdout.fileHandleForReading.fileDescriptor != stderr.fileHandleForReading.fileDescriptor {
        DispatchQueue.global().async(group: group) {
          stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
        }
      }

      stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
      try process.finish()
    } catch {
      throw JSONRPCSetupError
        .standardIOConnectionError(
          "Error loading environment: \(error). Stderr: \(String(data: stderrData, encoding: .utf8) ?? "")")
    }

    group.wait()

    return String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  #endif
}

// MARK: - Lifetime

final class Lifetime {

  init(onDeinit: @escaping () -> Void) {
    self.onDeinit = onDeinit
  }

  deinit {
    onDeinit()
  }

  private let onDeinit: () -> Void

}

extension Data {
  fileprivate func toLog(withTitle title: String) -> String {
    guard let string = String(data: self, encoding: .utf8), !string.isEmpty else { return "" }

    return """

      \(title):
      \(string)
      """
  }
}
