
import JSONRPC
import Testing
@testable import MCPClient

extension MCPClientConnectionTestSuite {
  final class ListResourceTemplatesTests: MCPClientConnectionTest {

    @Test("list resource templates")
    func test_listResourceTemplates() async throws {
      let resources = try await assert(
        executing: {
          try await self.sut.listResourceTemplates()
        },
        sends: """
          {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "resources/templates/list",
            "params": {}
          }
          """,
        receives: """
          {
            "jsonrpc": "2.0",
            "id": 1,
            "result": {
              "resourceTemplates": [
                {
                  "uriTemplate": "file:///{path}",
                  "name": "Project Files",
                  "description": "Access files in the project directory",
                  "mimeType": "application/octet-stream"
                }
              ]
            }
          }
          """)
      #expect(resources.map { $0.uriTemplate } == ["file:///{path}"])
    }

    @Test("list resource templates with pagination")
    func test_listResourceTemplates_withPagination() async throws {
      let resources = try await assert(
        executing: { try await self.sut.listResourceTemplates() },
        triggers: [
          .request("""
            {
              "jsonrpc": "2.0",
              "id": 1,
              "method": "resources/templates/list",
              "params": {}
            }
            """),
          .response("""
            {
              "jsonrpc": "2.0",
              "id": 1,
              "result": {
                "resourceTemplates": [
                  {
                    "uriTemplate": "file:///{path}",
                    "name": "Project Files",
                    "description": "Access files in the project directory",
                    "mimeType": "application/octet-stream"
                  }
                ],
                "nextCursor": "next-page-cursor"
              }
            }
            """),
          .request("""
            {
              "id" : 2,
              "jsonrpc" : "2.0",
              "method" : "resources/templates/list",
              "params" : {
                "cursor": "next-page-cursor"
              }
            }
            """),
          .response("""
            {
              "jsonrpc": "2.0",
              "id": 2,
              "result": {
                "resourceTemplates": [
                  {
                    "uriTemplate": "images:///{path}",
                    "name": "Project Images",
                    "description": "Access images in the project directory",
                    "mimeType": "image/jpeg"
                  }
                ]
              }
            }
            """),
        ])
      #expect(resources.map { $0.uriTemplate } == ["file:///{path}", "images:///{path}"])
    }

  }
}
