import Foundation

enum APIAuthMethod: String, CaseIterable, Codable, Identifiable {
    case automatic
    case bearer
    case xAPIKey

    var id: String { rawValue }

    func displayName(language: AppLanguage) -> String {
        switch (language, self) {
        case (.english, .automatic):
            "Automatic"
        case (.simplifiedChinese, .automatic):
            "自动"
        case (.english, .bearer):
            "Authorization Bearer"
        case (.simplifiedChinese, .bearer):
            "Authorization Bearer"
        case (.english, .xAPIKey):
            "x-api-key"
        case (.simplifiedChinese, .xAPIKey):
            "x-api-key"
        }
    }
}
