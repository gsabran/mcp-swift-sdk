
// Copied from https://github.com/kareman/SwiftShell/blob/99680b2efc7c7dbcace1da0b3979d266f02e213c/Sources/SwiftShell/Process.swift#L12-L59

import Foundation

// MARK: - Process Extensions (macOS only)

#if os(macOS)
extension Process {
  /// Launches process.
  ///
  /// - throws: CommandError.inAccessibleExecutable if command could not be executed.
  public func launchThrowably() throws {
    #if !os(macOS)
    guard Files.isExecutableFile(atPath: executableURL!.path) else {
      throw CommandError.inAccessibleExecutable(path: executableURL!.lastPathComponent)
    }
    #endif
    do {
      if #available(OSX 10.13, *) {
        try run()
      } else {
        launch()
      }
    } catch CocoaError.fileNoSuchFile {
      if #available(OSX 10.13, *) {
        throw CommandError.inAccessibleExecutable(path: self.executableURL!.lastPathComponent)
      } else {
        throw CommandError.inAccessibleExecutable(path: launchPath!)
      }
    }
  }

  /// Waits until process is finished.
  ///
  /// - throws: `CommandError.returnedErrorCode(command: String, errorcode: Int)`
  ///   if the exit code is anything but 0.
  public func finish() throws {
    /// The full path to the executable + all arguments, each one quoted if it contains a space.
    func commandAsString() -> String {
      let path: String =
        if #available(OSX 10.13, *) {
          self.executableURL?.path ?? ""
        } else {
          launchPath ?? ""
        }
      return (arguments ?? []).reduce(path) { (acc: String, arg: String) in
        acc + " " + (arg.contains(" ") ? ("\"" + arg + "\"") : arg)
      }
    }
    waitUntilExit()
    guard terminationStatus == 0 else {
      throw CommandError.returnedErrorCode(command: commandAsString(), errorcode: Int(terminationStatus))
    }
  }
}
#endif

// MARK: - CommandError

/// Error type for commands.
enum CommandError: Error, Equatable {
  /// Exit code was not zero.
  case returnedErrorCode(command: String, errorcode: Int)

  /// Command could not be executed.
  case inAccessibleExecutable(path: String)

  /// Exit code for this error.
  public var errorcode: Int {
    switch self {
    case .returnedErrorCode(_, let code):
      code
    case .inAccessibleExecutable:
      127 // according to http://tldp.org/LDP/abs/html/exitcodes.html
    }
  }
}

// MARK: CustomStringConvertible

extension CommandError: CustomStringConvertible {
  public var description: String {
    switch self {
    case .inAccessibleExecutable(let path):
      "Could not execute file at path '\(path)'."
    case .returnedErrorCode(let command, let code):
      "Command '\(command)' returned with error code \(code)."
    }
  }
}
