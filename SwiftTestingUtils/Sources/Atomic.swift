import os

final class Atomic<Value: Sendable>: Sendable {

  init(_ value: Value) {
    lock = .init(initialState: value)
  }

  var value: Value {
    lock.withLock { $0 }
  }

  @discardableResult
  func mutate<Result: Sendable>(_ mutation: @Sendable (inout Value) -> Result) -> Result {
    lock.withLock { mutation(&$0) }
  }

  private let lock: OSAllocatedUnfairLock<Value>

}
