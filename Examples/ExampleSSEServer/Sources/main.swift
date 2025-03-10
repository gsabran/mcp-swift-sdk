import os

let logger = Logger(subsystem: "com.mcp-sse-server", category: "mcp")

try await runWebServer(runMCPServerForConnection: { responseStream, requestStrean in
  try await startMCPServer(sendDataTo: responseStream, readDataFrom: requestStrean)
})
