
import JSONRPC
import MCPShared
import SwiftTestingUtils
import Testing
@testable import MCPClient

extension MCPClientTestSuite {

  class ServerRequests: MCPClientTest {

    @Test("List roots is sent to the handler when provided")
    func test_listRootsIsSuccessfulWhenHandled() async throws {
      let expectation = expectation(description: "The request is responded to")
      let root = Root(uri: "//root", name: "root")
      let listRootsRequestHandler: ListRootsRequestHandler = { _ in
        .init(roots: [root])
      }

      let sut = try await createMCPClient(listRootRequestHandler: listRootsRequestHandler)
      let request = ServerRequest.listRoots()

      connection.sendRequestToStream((request, { response in
        do {
          let success = try response.get()
          let roots = try #require(success as? ListRootsResult)
          #expect(roots.roots.map { $0.uri } == ["//root"])
          expectation.fulfill()
        } catch {
          Issue.record(error)
        }
      }))

      try await fulfillment(of: expectation)
      _ = sut
    }

    @Test("List roots fails when no handler is provided")
    func test_listRootsFailsWhenNotHandled() async throws {
      let expectation = expectation(description: "The request is responded to")

      let sut = try await createMCPClient(listRootRequestHandler: nil)
      let request = ServerRequest.listRoots()

      connection.sendRequestToStream((request, { response in
        switch response {
        case .success:
          Issue.record("unexpected success")
        case .failure(let error):

          #expect(error.message == "Listing roots is not supported by this client")
        }
        expectation.fulfill()
      }))

      try await fulfillment(of: expectation)
      _ = sut
    }
  }

}
