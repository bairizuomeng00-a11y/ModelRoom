import Foundation

struct ChatTurn: Identifiable, Codable, Equatable {
    var id: UUID
    var prompt: String
    var answers: [ModelAnswer]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        prompt: String,
        answers: [ModelAnswer] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.prompt = prompt
        self.answers = answers
        self.createdAt = createdAt
    }
}

struct ChatSession: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var turns: [ChatTurn]
    var folderID: UUID?
    var isArchived: Bool
    var prompt: String
    var answers: [ModelAnswer]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "",
        turns: [ChatTurn] = [],
        folderID: UUID? = nil,
        isArchived: Bool = false,
        prompt: String = "",
        answers: [ModelAnswer] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.turns = turns
        self.folderID = folderID
        self.isArchived = isArchived
        self.prompt = prompt
        self.answers = answers
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case turns
        case folderID
        case isArchived
        case prompt
        case answers
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        folderID = try container.decodeIfPresent(UUID.self, forKey: .folderID)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        prompt = try container.decodeIfPresent(String.self, forKey: .prompt) ?? ""
        answers = try container.decodeIfPresent([ModelAnswer].self, forKey: .answers) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt

        let decodedTurns = try container.decodeIfPresent([ChatTurn].self, forKey: .turns) ?? []
        if decodedTurns.isEmpty && (!prompt.isEmpty || !answers.isEmpty) {
            turns = [ChatTurn(prompt: prompt, answers: answers, createdAt: updatedAt)]
        } else {
            turns = decodedTurns
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(turns, forKey: .turns)
        try container.encodeIfPresent(folderID, forKey: .folderID)
        try container.encode(isArchived, forKey: .isArchived)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)

        let lastTurn = turns.last
        try container.encode(lastTurn?.prompt ?? prompt, forKey: .prompt)
        try container.encode(lastTurn?.answers ?? answers, forKey: .answers)
    }
}
