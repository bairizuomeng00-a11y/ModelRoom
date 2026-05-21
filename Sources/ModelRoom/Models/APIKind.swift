import Foundation

enum APIKind: String, CaseIterable, Codable, Identifiable {
    case openAICompatible
    case anthropicMessages

    var id: String { rawValue }

    var displayName: String {
        displayName(language: .english)
    }

    func displayName(language: AppLanguage) -> String {
        switch (language, self) {
        case (.english, .openAICompatible):
            "OpenAI Compatible"
        case (.simplifiedChinese, .openAICompatible):
            "OpenAI 兼容接口"
        case (.english, .anthropicMessages):
            "Anthropic Messages"
        case (.simplifiedChinese, .anthropicMessages):
            "Anthropic Messages 接口"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .openAICompatible:
            "https://api.openai.com"
        case .anthropicMessages:
            "https://api.anthropic.com"
        }
    }

    var defaultPath: String {
        switch self {
        case .openAICompatible:
            "/v1/chat/completions"
        case .anthropicMessages:
            "/v1/messages"
        }
    }
}
