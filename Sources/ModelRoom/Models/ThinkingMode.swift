import Foundation

enum ThinkingMode: String, CaseIterable, Codable, Identifiable {
    case off
    case low
    case medium
    case high

    var id: String { rawValue }

    var isEnabled: Bool {
        self != .off
    }

    var openAIReasoningEffort: String? {
        switch self {
        case .off:
            nil
        case .low:
            "low"
        case .medium:
            "medium"
        case .high:
            "high"
        }
    }

    func displayName(language: AppLanguage) -> String {
        switch (language, self) {
        case (.english, .off):
            "Off"
        case (.simplifiedChinese, .off):
            "关闭"
        case (.english, .low):
            "Low"
        case (.simplifiedChinese, .low):
            "低"
        case (.english, .medium):
            "Medium"
        case (.simplifiedChinese, .medium):
            "中"
        case (.english, .high):
            "High"
        case (.simplifiedChinese, .high):
            "高"
        }
    }

    func explanation(language: AppLanguage, apiKind: APIKind) -> String {
        switch (language, self, apiKind) {
        case (.english, .off, _):
            "No extra thinking parameter will be sent."
        case (.simplifiedChinese, .off, _):
            "不会额外发送思考参数。"
        case (.english, _, .openAICompatible):
            "Sends reasoning_effort to compatible Chat Completions endpoints."
        case (.simplifiedChinese, _, .openAICompatible):
            "会向兼容的 Chat Completions 接口发送 reasoning_effort 参数。"
        case (.english, _, .anthropicMessages):
            "Sends Anthropic thinking with an automatic token budget."
        case (.simplifiedChinese, _, .anthropicMessages):
            "会发送 Anthropic thinking 参数，并自动分配思考预算。"
        }
    }

    func anthropicBudgetTokens(maxTokens: Int) -> Int? {
        guard isEnabled, maxTokens > 1024 else { return nil }

        let ratio: Double
        switch self {
        case .off:
            return nil
        case .low:
            ratio = 0.20
        case .medium:
            ratio = 0.35
        case .high:
            ratio = 0.50
        }

        let computed = Int(Double(maxTokens) * ratio)
        return min(max(1024, computed), maxTokens - 1)
    }
}

