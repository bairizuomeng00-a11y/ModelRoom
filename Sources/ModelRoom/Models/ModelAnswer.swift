import Foundation

enum AnswerStatus: Equatable, Codable {
    case waiting
    case running
    case finished
    case failed(String)

    var label: String {
        switch self {
        case .waiting:
            AppLanguage.english.text(.waiting)
        case .running:
            AppLanguage.english.text(.thinking)
        case .finished:
            AppLanguage.english.text(.done)
        case .failed:
            AppLanguage.english.text(.error)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case message
    }

    private enum Kind: String, Codable {
        case waiting
        case running
        case finished
        case failed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .waiting:
            self = .waiting
        case .running:
            self = .running
        case .finished:
            self = .finished
        case .failed:
            self = .failed(try container.decodeIfPresent(String.self, forKey: .message) ?? "")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .waiting:
            try container.encode(Kind.waiting, forKey: .kind)
        case .running:
            try container.encode(Kind.running, forKey: .kind)
        case .finished:
            try container.encode(Kind.finished, forKey: .kind)
        case let .failed(message):
            try container.encode(Kind.failed, forKey: .kind)
            try container.encode(message, forKey: .message)
        }
    }
}

struct ModelAnswer: Identifiable, Equatable, Codable {
    var id = UUID()
    var providerID: UUID
    var providerName: String
    var modelName: String
    var status: AnswerStatus
    var content: String
    var startedAt: Date
    var finishedAt: Date?

    var elapsedText: String {
        guard let finishedAt else { return "" }
        let seconds = finishedAt.timeIntervalSince(startedAt)
        return String(format: "%.1fs", seconds)
    }
}
