// MARK: - MCP

public enum MCP {
  public static let protocolVersion = "2024-11-05"
}

extension String {
  /// Key for the meta parameter
  static var _meta: String { "_meta" }
}

// MARK: - Notifications

enum Notifications {
  static var cancelled: String { "notifications/cancelled" }
  static var initialized: String { "notifications/initialized" }
  static var progress: String { "notifications/progress" }
  static var resourceListChanged: String { "notifications/resources/list_changed" }
  static var resourceUpdated: String { "notifications/resources/updated" }
  static var promptListChanged: String { "notifications/prompts/list_changed" }
  static var toolListChanged: String { "notifications/tools/list_changed" }
  static var loggingMessage: String { "notifications/message" }
  static var rootsListChanged: String { "notifications/roots/list_changed" }
}

// MARK: - Requests

enum Requests {
  static var createMessage: String { "sampling/createMessage" }
  static var listRoots: String { "roots/list" }
  static var initialize: String { "initialize" }
  static var ping: String { "ping" }
  static var listResources: String { "resources/list" }
  static var listResourceTemplates: String { "resources/templates/list" }
  static var readResource: String { "resources/read" }
  static var subscribeToResource: String { "resources/subscribe" }
  static var unsubscribeToResource: String { "resources/unsubscribe" }
  static var listPrompts: String { "prompts/list" }
  static var getPrompt: String { "prompts/get" }
  static var listTools: String { "tools/list" }
  static var callTool: String { "tools/call" }
  static var setLoggingLevel: String { "logging/setLevel" }
  static var autocomplete: String { "completion/complete" }
}
