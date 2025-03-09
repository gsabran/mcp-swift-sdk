import Foundation

/// A URI Template implementation conforming to RFC 6570
public struct URITemplate {
    // オリジナルのテンプレートパターン
    public let pattern: String
    
    // 変数名と修飾子のマッピング
    private let variables: [(name: String, modifier: Character?)]
    
    // マッチング用の正規表現
    private let matchRegex: NSRegularExpression
    
    public init(_ pattern: String) throws {
        self.pattern = pattern
        
        // 正規表現でテンプレート変数を抽出
        let variableRegex = try NSRegularExpression(pattern: "\\{([+#./&?])?([^}]+)\\}")
        let range = NSRange(location: 0, length: pattern.utf16.count)
        let matches = variableRegex.matches(in: pattern, range: range)
        
        // 変数と修飾子を抽出
        var extractedVars: [(name: String, modifier: Character?)] = []
        for match in matches {
            if match.numberOfRanges > 2 {
                let modifierRange = match.range(at: 1)
                let nameRange = match.range(at: 2)
                
                let modifier: Character? = modifierRange.location != NSNotFound
                ? (Range(modifierRange, in: pattern).map { pattern[$0].first }) ?? nil
                : nil
                
                if let nameRange = Range(nameRange, in: pattern) {
                    let nameString = String(pattern[nameRange])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // 複数変数対応 (name,id)
                    for varName in nameString.split(separator: ",") {
                        let cleanName = varName.trimmingCharacters(in: .whitespacesAndNewlines)
                        extractedVars.append((String(cleanName), modifier))
                    }
                }
            }
        }
        self.variables = extractedVars
        
        // マッチング用正規表現を生成
        var regexPattern = "^"
        var currentIndex = 0
        
        for match in matches {
            // マッチ前の静的テキスト部分
            if let startIndex = pattern.index(pattern.startIndex, offsetBy: currentIndex, limitedBy: pattern.endIndex),
               let matchStartIndex = pattern.index(pattern.startIndex, offsetBy: match.range.location, limitedBy: pattern.endIndex) {
                let prefix = pattern[startIndex..<matchStartIndex]
                regexPattern += NSRegularExpression.escapedPattern(for: String(prefix))
            }
            
            // 変数部分をキャプチャグループに置き換え
            let capturePattern: String
            if let modifierRange = Range(match.range(at: 1), in: pattern),
               let modifier = pattern[modifierRange].first {
                
                // 修飾子に基づいたキャプチャパターン
                if modifier == "?" || modifier == "&" {
                    // クエリパラメータ用
                    capturePattern = "([^&]+)"
                } else if modifier == "+" || modifier == "#" {
                    // 予約文字保持用
                    capturePattern = "([^/]+(?:/[^/]+)*)"
                } else {
                    // 標準
                    capturePattern = "([^/]+)"
                }
            } else {
                // 修飾子なし
                capturePattern = "([^/]+)"
            }
            regexPattern += capturePattern
            
            currentIndex = match.range.location + match.range.length
        }
        
        // 末尾の静的テキスト部分
        if let startIndex = pattern.index(pattern.startIndex, offsetBy: currentIndex, limitedBy: pattern.endIndex) {
            let suffix = pattern[startIndex...]
            regexPattern += NSRegularExpression.escapedPattern(for: String(suffix))
        }
        
        regexPattern += "$"
        self.matchRegex = try NSRegularExpression(pattern: regexPattern)
    }
    
    public func expand(_ variables: [String: Any]) -> String {
        var result = pattern
        
        // {var} 部分を実際の値に置き換え
        for (name, value) in variables {
            let variablePattern = "\\{([+#./&?])?([^}]*,)?(\(name))(,[^}]*)?\\}"
            do {
                let regex = try NSRegularExpression(pattern: variablePattern)
                let range = NSRange(location: 0, length: result.utf16.count)
                
                // すべてのマッチを逆順で処理（置換で文字列の長さが変わるため）
                let matches = regex.matches(in: result, range: range).reversed()
                for match in matches {
                    if let fullRange = Range(match.range(at: 0), in: result) {
                        let modifierRange = match.range(at: 1)
                        
                        // 修飾子があれば抽出
                        let modifier: Character? = modifierRange.location != NSNotFound
                        ? (Range(modifierRange, in: result).map { result[$0].first }) ?? nil
                        : nil
                        
                        // 展開された値を生成
                        let expandedValue = formatVariableValue(value, with: modifier)
                        
                        // 置換実行
                        result.replaceSubrange(fullRange, with: expandedValue)
                    }
                }
            } catch {
                // 正規表現エラーは無視
                continue
            }
        }
        
        // 未展開の変数を削除
        do {
            let unexpandedVarRegex = try NSRegularExpression(pattern: "\\{([+#./&?])?[^}]*\\}")
            let range = NSRange(location: 0, length: result.utf16.count)
            let matches = unexpandedVarRegex.matches(in: result, range: range).reversed()
            
            for match in matches {
                if let range = Range(match.range, in: result) {
                    result.replaceSubrange(range, with: "")
                }
            }
        } catch {
            // 正規表現エラーは無視
        }
        
        return result
    }
    
    private func formatVariableValue(_ value: Any, with modifier: Character?) -> String {
        let stringValue: String
        
        // 値をフォーマット
        if let array = value as? [Any] {
            stringValue = array.map { String(describing: $0) }.joined(separator: ",")
        } else {
            stringValue = String(describing: value)
        }
        
        // 修飾子に基づいた処理
        if let modifier = modifier {
            switch modifier {
            case "+":
                // 予約文字をエンコードしない
                return stringValue
            case "#":
                // フラグメント
                return "#" + stringValue
            case "?":
                // クエリパラメータの開始
                return "?" + stringValue
            case "&":
                // 追加クエリパラメータ
                return "&" + stringValue
            case ".":
                // ドット区切り
                return "." + stringValue
            case "/":
                // スラッシュ区切り
                return "/" + stringValue
            default:
                return stringValue
            }
        }
        
        // 修飾子なしの場合は通常のURLエンコード
        return stringValue.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? stringValue
    }
    
    public func match(_ uri: String) -> [String: String]? {
        let range = NSRange(location: 0, length: uri.utf16.count)
        guard let match = matchRegex.firstMatch(in: uri, range: range) else {
            return nil
        }
        
        var result: [String: String] = [:]
        
        // キャプチャグループから値を抽出
        for (index, variable) in variables.enumerated() {
            let captureIndex = index + 1
            if captureIndex < match.numberOfRanges {
                let captureRange = match.range(at: captureIndex)
                if captureRange.location != NSNotFound, let range = Range(captureRange, in: uri) {
                    let value = String(uri[range])
                    result[variable.name] = value
                }
            }
        }
        
        return result.isEmpty ? nil : result
    }
}

// MARK: - URITemplateError

/// Errors that can occur during URI template processing
public enum URITemplateError: Error, LocalizedError {
    /// Invalid template pattern
    case invalidPattern(String)
    /// Invalid regex pattern
    case invalidRegexPattern(pattern: String, error: Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidPattern(let pattern):
            return "Invalid URI template pattern: \(pattern)"
        case .invalidRegexPattern(let pattern, let error):
            return "Invalid regex pattern: \(pattern) - \(error.localizedDescription)"
        }
    }
}

// MARK: - CustomStringConvertible
extension URITemplate: CustomStringConvertible {
    public var description: String {
        return pattern
    }
}

// MARK: - Equatable
extension URITemplate: Equatable {
    public static func == (lhs: URITemplate, rhs: URITemplate) -> Bool {
        return lhs.pattern == rhs.pattern
    }
}
