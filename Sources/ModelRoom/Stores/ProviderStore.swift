import Foundation

enum ProviderStore {
    private static let providersKey = "providers.v1"
    private static let indexFileName = "index.json"
    private static let configFileName = "config.json"

    private struct ProviderIndex: Codable {
        var orderedIDs: [UUID]
    }

    static func load() -> [ProviderConfig] {
        if let providers = loadFromProviderDirectories(), !providers.isEmpty {
            return providers
        }

        if let migrated = loadLegacyProviders(), !migrated.isEmpty {
            saveMetadata(migrated)
            return migrated
        }

        let defaults = [
            ProviderConfig(name: "OpenAI", kind: .openAICompatible, model: "gpt-4.1"),
            ProviderConfig(name: "Claude", kind: .anthropicMessages, model: "claude-sonnet-4-5")
        ]
        saveMetadata(defaults)
        return defaults
    }

    static func saveMetadata(_ providers: [ProviderConfig]) {
        do {
            try ensureProvidersDirectory()
            try saveIndex(providers.map(\.id))
            for provider in providers {
                try saveConfig(provider)
            }
            try removeOrphanProviderDirectories(keeping: Set(providers.map(\.id)))
        } catch {
            fallbackSaveMetadata(providers)
        }
    }

    static func deleteProvider(for providerID: UUID) {
        let directory = providerDirectory(for: providerID)
        try? FileManager.default.removeItem(at: directory)
    }

    private static func loadFromProviderDirectories() -> [ProviderConfig]? {
        guard let index = loadIndex() else { return nil }
        let providers = index.orderedIDs.compactMap(loadConfig)
        return providers.isEmpty ? nil : providers
    }

    private static func loadConfig(providerID: UUID) -> ProviderConfig? {
        let fileURL = providerDirectory(for: providerID).appendingPathComponent(configFileName)
        guard let data = try? Data(contentsOf: fileURL),
              let stored = try? JSONDecoder().decode(StoredProviderConfig.self, from: data) else {
            return nil
        }

        return stored.hydrated(apiKey: "")
    }

    private static func loadLegacyProviders() -> [ProviderConfig]? {
        guard let data = UserDefaults.standard.data(forKey: providersKey),
              let stored = try? JSONDecoder().decode([StoredProviderConfig].self, from: data) else {
            return nil
        }

        return stored.map { item in item.hydrated(apiKey: "") }
    }

    private static func saveConfig(_ provider: ProviderConfig) throws {
        let directory = providerDirectory(for: provider.id)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent(configFileName)
        let data = try JSONEncoder.pretty.encode(StoredProviderConfig(provider))
        try data.write(to: fileURL, options: [.atomic])
    }

    private static func saveIndex(_ orderedIDs: [UUID]) throws {
        let data = try JSONEncoder.pretty.encode(ProviderIndex(orderedIDs: orderedIDs))
        try data.write(to: providersDirectory.appendingPathComponent(indexFileName), options: [.atomic])
    }

    private static func removeOrphanProviderDirectories(keeping providerIDs: Set<UUID>) throws {
        let contents = try FileManager.default.contentsOfDirectory(
            at: providersDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        for url in contents {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true,
                  let id = UUID(uuidString: url.lastPathComponent),
                  !providerIDs.contains(id) else {
                continue
            }
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func loadIndex() -> ProviderIndex? {
        let fileURL = providersDirectory.appendingPathComponent(indexFileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(ProviderIndex.self, from: data)
    }

    private static func fallbackSaveMetadata(_ providers: [ProviderConfig]) {
        let stored = providers.map(StoredProviderConfig.init)
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: providersKey)
        }
    }

    private static func ensureProvidersDirectory() throws {
        try FileManager.default.createDirectory(at: providersDirectory, withIntermediateDirectories: true)
    }

    private static var providersDirectory: URL {
        applicationSupportDirectory
            .appendingPathComponent("ModelRoom", isDirectory: true)
            .appendingPathComponent("Providers", isDirectory: true)
    }

    private static var applicationSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
    }

    private static func providerDirectory(for providerID: UUID) -> URL {
        providersDirectory.appendingPathComponent(providerID.uuidString, isDirectory: true)
    }

}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
