import Foundation

enum ChatFolderStore {
    private static let foldersKey = "chatFolders.v1"

    static func load() -> [ChatFolder] {
        guard let data = UserDefaults.standard.data(forKey: foldersKey),
              let folders = try? JSONDecoder().decode([ChatFolder].self, from: data) else {
            return []
        }

        return folders
    }

    static func save(_ folders: [ChatFolder]) {
        if let data = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(data, forKey: foldersKey)
        }
    }
}
