import Foundation
import MCPInterface
import JSONSchema
import JSONSchemaBuilder

struct PromptHandler {
    let prompt: Prompt
    let execute: (JSON?) async throws -> GetPromptResult
    let completionCallback: (String, String) async throws -> [String]
    
    // 特定のフィールド名に対する完了候補コールバックを取得
    func completionCallback(for fieldName: String) -> ((String) async throws -> [String])? {
        return { value in
            return try await self.completionCallback(fieldName, value)
        }
    }
}
