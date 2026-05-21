import Foundation

enum ChatSessionStore {
    private static let sessionsKey = "chatSessions.v1"

    static func load() -> [ChatSession] {
        guard let data = UserDefaults.standard.data(forKey: sessionsKey),
              let sessions = try? JSONDecoder().decode([ChatSession].self, from: data) else {
            return [ChatSession()]
        }

        return sessions.isEmpty ? [ChatSession()] : sessions
    }

    static func save(_ sessions: [ChatSession]) {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
    }
}
