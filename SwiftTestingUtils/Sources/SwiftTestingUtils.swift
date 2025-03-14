import Foundation
import os
import OSLog
import Testing

private let logger = Logger(subsystem: "testing", category: "testing")

// MARK: - SwiftTestingUtils

public enum SwiftTestingUtils {

  public final class Expectation: Sendable {

    init(
      description: String,
      _sourceLocation: SourceLocation = #_sourceLocation)
    {
      self.description = description
      location = _sourceLocation
    }

    public var isFulfilled: Bool {
      lock.withLock { $0.isFulfilled }
    }

    public func fulfill() {
      let (wasFulfilled, fullfillmentActions) = lock.withLock { state in
        let wasFulfilled = state.isFulfilled
        state.isFulfilled = true
        return (wasFulfilled, state.onFulfill)
      }

      if wasFulfilled {
        Issue.record("Expectation from \(location) already fulfilled.")
        return
      }
      for fullfillmentAction in fullfillmentActions { fullfillmentAction() }
    }

    let description: String
    let location: SourceLocation

    func fulfillment(timeout: TimeInterval = 1) async throws {
      if isFulfilled {
        return
      }

      let hasTimedOut = Atomic(false)
      let description = description

      try await withCheckedThrowingContinuation { continuation in
        let onFulfill: @Sendable () -> Void = {
          if !hasTimedOut.value {
            continuation.resume(returning: ())
          } else {
            logger.error("Expectation \(description) fulfilled after timeout.")
          }
        }
        let wasFulfilled = lock.withLock { state in
          if state.isFulfilled {
            return true
          }
          state.onFulfill.append(onFulfill)
          return false
        }
        if wasFulfilled {
          continuation.resume(returning: ())
        }
        Task {
          do {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            if !isFulfilled {
              hasTimedOut.mutate { $0 = true }
              continuation.resume(throwing: SwiftTesting.expectationTimeout(description: description))
            }
          } catch {
            continuation.resume(throwing: error)
          }
        }
      }
    }

    private struct InternalState {
      var isFulfilled = false
      var onFulfill: [@Sendable () -> Void] = []
    }

    private let lock = OSAllocatedUnfairLock<InternalState>(initialState: InternalState())
  }

  enum SwiftTesting: Error {
    case expectationTimeout(description: String)
    case genericError(_ message: String)
  }
}

/// Create an expectation.
/// Like for `XCTestExpectation`, this expectation should be awaited during the test, and fulfilled only once.
public func expectation(description: String, _sourceLocation: SourceLocation = #_sourceLocation) -> SwiftTestingUtils
  .Expectation
{
  SwiftTestingUtils.Expectation(description: description, _sourceLocation: _sourceLocation)
}

/// Wait for an expectation to be fulfilled, or throw an error after the timeout.
public func fulfillment(of expectation: SwiftTestingUtils.Expectation, timeout: TimeInterval = 1) async throws {
  try await expectation.fulfillment(timeout: timeout)
}

/// Wait for the expectations to be fulfilled, or throw an error after the timeout.
public func fulfillment(of expectations: [SwiftTestingUtils.Expectation], timeout: TimeInterval = 1) async throws {
  for expectation in expectations {
    try await expectation.fulfillment(timeout: timeout)
  }
}

// MARK: - Issue + Error

extension Issue: @retroactive Error { }
