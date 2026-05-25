import AppKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var providers: [ProviderConfig]
    @Published var selectedProviderID: UUID?
    @Published var sessions: [ChatSession]
    @Published var folders: [ChatFolder]
    @Published var selectedSessionID: UUID?
    @Published var prompt: String = ""
    @Published var isRunning = false
    @Published var updateStatus: ManualUpdateStatus = .idle
    @Published var pendingUndoDeletion: PendingUndoDeletion?
    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey)
            SettingsWindowPresenter.updateTitle(language: language)
        }
    }

    private let client = ModelAPIClient()
    private let updater = AppUpdater()
    private var pendingUndoHandler: (@MainActor () -> Void)?
    private var pendingUndoTask: Task<Void, Never>?
    private static let languageKey = "appLanguage.v1"

    init() {
        let loadedProviders = ProviderStore.load()
        var loadedSessions = ChatSessionStore.load()
        var loadedFolders = ChatFolderStore.load()
        let storedLanguage = UserDefaults.standard.string(forKey: Self.languageKey)
        let normalizedProviders = loadedProviders.map(ProviderEndpointPolicy.normalized)
        Self.migrateArchivedSessions(&loadedSessions, folders: &loadedFolders)
        providers = normalizedProviders
        sessions = loadedSessions
        folders = loadedFolders
        selectedProviderID = normalizedProviders.first?.id
        selectedSessionID = loadedSessions.first?.id
        language = storedLanguage.flatMap(AppLanguage.init(rawValue:)) ?? .simplifiedChinese
        ProviderStore.saveMetadata(normalizedProviders)
        ChatSessionStore.save(loadedSessions)
        ChatFolderStore.save(loadedFolders)
    }

    var selectedProvider: ProviderConfig? {
        guard let selectedProviderID else { return nil }
        return providers.first { $0.id == selectedProviderID }
    }

    var runnableProviders: [ProviderConfig] {
        providers.filter(\.isRunnable)
    }

    var selectedSession: ChatSession? {
        guard let selectedSessionID else { return nil }
        return sessions.first { $0.id == selectedSessionID }
    }

    var selectedAnswers: [ModelAnswer] {
        selectedSession?.turns.last?.answers ?? []
    }

    var selectedQuestion: String {
        selectedSession?.turns.last?.prompt ?? ""
    }

    var selectedTurns: [ChatTurn] {
        selectedSession?.turns ?? []
    }

    var rootSessions: [ChatSession] {
        sessions(in: nil)
    }

    var rootFolders: [ChatFolder] {
        childFolders(of: nil)
    }

    func addProvider(kind: APIKind = .openAICompatible) {
        let provider = ProviderConfig(
            name: language.text(.newProvider),
            kind: kind,
            model: kind == .openAICompatible ? "gpt-4.1" : "claude-sonnet-4-5"
        )
        providers.append(provider)
        selectedProviderID = provider.id
        saveProviderMetadata()
    }

    func duplicateSelectedProvider() {
        guard let provider = selectedProvider else { return }
        var copy = provider
        copy.id = UUID()
        copy.name = language == .english ? "\(provider.name) Copy" : "\(provider.name) 副本"
        providers.append(copy)
        selectedProviderID = copy.id
        saveProviderMetadata()
    }

    func deleteSelectedProvider() {
        guard let selectedProviderID,
              let removedIndex = providers.firstIndex(where: { $0.id == selectedProviderID }) else {
            self.selectedProviderID = providers.first?.id
            return
        }

        let removedProvider = providers[removedIndex]
        self.selectedProviderID = nil
        providers.remove(at: removedIndex)
        ProviderStore.deleteProvider(for: selectedProviderID)

        if providers.isEmpty {
            self.selectedProviderID = nil
        } else {
            let nextIndex = min(removedIndex, providers.count - 1)
            self.selectedProviderID = providers[nextIndex].id
        }
        saveProviderMetadata()

        showUndoDeletion(
            message: language.text(.modelDeleted),
            systemImage: "slider.horizontal.3"
        ) { [weak self] in
            guard let self else { return }
            if !self.providers.contains(where: { $0.id == removedProvider.id }) {
                self.providers.insert(removedProvider, at: min(removedIndex, self.providers.count))
            }
            self.selectedProviderID = removedProvider.id
            self.saveProviderMetadata()
        }
    }

    func setProviderEnabled(_ isEnabled: Bool, providerID: UUID) {
        guard let index = providers.firstIndex(where: { $0.id == providerID }) else { return }
        providers[index].isEnabled = isEnabled
        saveProviderMetadata()
    }

    func updateProvider(_ provider: ProviderConfig) {
        guard let index = providers.firstIndex(where: { $0.id == provider.id }) else { return }
        let adjusted = ProviderEndpointPolicy.normalized(provider)
        providers[index] = adjusted
        saveProviderMetadata()
    }

    func resetEndpointForSelectedProvider() {
        guard var provider = selectedProvider else { return }
        provider.baseURL = provider.kind.defaultBaseURL
        provider.endpointPath = provider.kind.defaultPath
        updateProvider(provider)
    }

    func runManualUpdate() {
        guard !updateStatus.isInProgress else { return }
        updateStatus = .checking

        Task {
            do {
                let release = try await updater.latestRelease()
                let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
                guard updater.isRelease(release, newerThan: currentVersion) else {
                    updateStatus = .upToDate(release.tagName)
                    return
                }

                updateStatus = .downloading
                let result = try await updater.downloadDMG(from: release)
                updateStatus = .downloaded(result.tagName)
                NSWorkspace.shared.open(result.fileURL)
            } catch {
                updateStatus = .failed(error.localizedDescription)
            }
        }
    }

    func newChat() {
        let session = ChatSession()
        sessions.insert(session, at: 0)
        selectedSessionID = session.id
        prompt = ""
        saveSessions()
    }

    func newFolder(parentID: UUID? = nil) {
        let parent = parentID.flatMap { folder(id: $0) }
        let newFolder = ChatFolder(
            name: language.text(.newFolder),
            parentID: parent?.id
        )
        folders.append(newFolder)
        saveFolders()
    }

    func deleteSelectedChat() {
        guard let selectedSessionID else { return }

        guard let removedIndex = sessions.firstIndex(where: { $0.id == selectedSessionID }) else {
            self.selectedSessionID = sessions.first?.id
            return
        }

        let removedSession = sessions.remove(at: removedIndex)
        var placeholderID: UUID?
        if sessions.isEmpty {
            let placeholder = ChatSession()
            placeholderID = placeholder.id
            sessions.append(placeholder)
        }
        self.selectedSessionID = sessions.first?.id
        prompt = ""
        saveSessions()

        showUndoDeletion(
            message: language.text(.chatDeleted),
            systemImage: "bubble.left.and.text.bubble.right"
        ) { [weak self] in
            guard let self else { return }
            if let placeholderID,
               let placeholderIndex = self.sessions.firstIndex(where: { $0.id == placeholderID }),
               self.sessions[placeholderIndex].title.isEmpty,
               self.sessions[placeholderIndex].turns.isEmpty,
               self.sessions[placeholderIndex].prompt.isEmpty,
               self.sessions[placeholderIndex].answers.isEmpty {
                self.sessions.remove(at: placeholderIndex)
            }
            if !self.sessions.contains(where: { $0.id == removedSession.id }) {
                self.sessions.insert(removedSession, at: min(removedIndex, self.sessions.count))
            }
            self.selectedSessionID = removedSession.id
            self.saveSessions()
        }
    }

    func sessions(in folderID: UUID?) -> [ChatSession] {
        sessions.filter { $0.folderID == folderID }
    }

    func childFolders(of parentID: UUID?) -> [ChatFolder] {
        folders.filter { $0.parentID == parentID }
    }

    func folder(id: UUID) -> ChatFolder? {
        folders.first { $0.id == id }
    }

    func itemCount(in folderID: UUID?) -> Int {
        sessions(in: folderID).count + childFolders(of: folderID).count
    }

    func renameFolder(id: UUID, name: String) {
        guard let index = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[index].name = name
        folders[index].updatedAt = Date()
        saveFolders()
    }

    func moveSession(_ sessionID: UUID, to folderID: UUID?) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        let destination = folderID.flatMap { folder(id: $0) }
        guard folderID == nil || destination != nil else { return }
        sessions[index].folderID = destination?.id
        sessions[index].isArchived = false
        sessions[index].updatedAt = Date()
        saveSessions()
    }

    func moveFolder(_ folderID: UUID, to parentID: UUID?) {
        guard let index = folders.firstIndex(where: { $0.id == folderID }) else { return }
        let destination = parentID.flatMap { folder(id: $0) }
        guard parentID == nil || destination != nil else { return }
        guard folderID != parentID else { return }
        guard !isFolder(parentID, descendantOf: folderID) else { return }

        folders[index].parentID = destination?.id
        folders[index].updatedAt = Date()
        saveFolders()
    }

    func deleteFolder(_ folderID: UUID) {
        guard let folder = folder(id: folderID) else { return }
        let removedFolderIDs = descendantFolderIDs(of: folderID).union([folderID])
        let removedFolders: [(index: Int, folder: ChatFolder)] = folders.enumerated().compactMap { index, item in
            removedFolderIDs.contains(item.id) ? (index, item) : nil
        }
        let affectedSessions = sessions.filter { session in
            session.folderID.map(removedFolderIDs.contains) == true
        }

        for index in sessions.indices where sessions[index].folderID.map(removedFolderIDs.contains) == true {
            sessions[index].folderID = folder.parentID
            sessions[index].updatedAt = Date()
        }

        folders.removeAll { removedFolderIDs.contains($0.id) }
        saveFolders()
        saveSessions()

        showUndoDeletion(
            message: language.text(.folderDeleted),
            systemImage: "folder"
        ) { [weak self] in
            guard let self else { return }

            for removed in removedFolders.sorted(by: { $0.index < $1.index }) {
                if !self.folders.contains(where: { $0.id == removed.folder.id }) {
                    self.folders.insert(removed.folder, at: min(removed.index, self.folders.count))
                }
            }

            for snapshot in affectedSessions {
                guard let index = self.sessions.firstIndex(where: { $0.id == snapshot.id }) else { continue }
                self.sessions[index].folderID = snapshot.folderID
                self.sessions[index].isArchived = snapshot.isArchived
                self.sessions[index].updatedAt = snapshot.updatedAt
            }

            self.saveFolders()
            self.saveSessions()
        }
    }

    func undoPendingDeletion() {
        guard let undo = pendingUndoHandler else { return }
        clearPendingUndoDeletion()
        undo()
    }

    func submitPrompt() {
        let text = prompt.trimmed
        let targets = runnableProviders
        guard !text.isEmpty, !targets.isEmpty, !isRunning else { return }

        let sessionID = ensureSelectedSession()
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }

        let previousTurns = sessions[index].turns
        let turnID = UUID()
        let pendingAnswers = targets.map {
            ModelAnswer(
                providerID: $0.id,
                providerName: $0.name,
                modelName: $0.model,
                status: .running,
                content: "",
                startedAt: Date(),
                finishedAt: nil
            )
        }

        isRunning = true
        sessions[index].prompt = text
        if sessions[index].title.trimmed.isEmpty {
            sessions[index].title = Self.title(for: text)
        }
        sessions[index].updatedAt = Date()
        sessions[index].answers = pendingAnswers
        sessions[index].turns.append(ChatTurn(id: turnID, prompt: text, answers: pendingAnswers))
        prompt = ""
        saveSessions()

        Task {
            await runBatch(
                prompt: text,
                providers: targets,
                sessionID: sessionID,
                turnID: turnID,
                previousTurns: previousTurns
            )
        }
    }

    private func runBatch(
        prompt: String,
        providers: [ProviderConfig],
        sessionID: UUID,
        turnID: UUID,
        previousTurns: [ChatTurn]
    ) async {
        await withTaskGroup(of: (UUID, Result<ModelReply, Error>).self) { group in
            for provider in providers {
                let messages = contextMessages(for: provider, previousTurns: previousTurns, newPrompt: prompt)
                group.addTask {
                    do {
                        let reply = try await self.client.send(messages: messages, provider: provider)
                        return (provider.id, .success(reply))
                    } catch {
                        return (provider.id, .failure(error))
                    }
                }
            }

            for await (providerID, result) in group {
                updateAnswer(sessionID: sessionID, turnID: turnID, providerID: providerID, result: result)
            }
        }

        isRunning = false
        saveSessions()
    }

    private func updateAnswer(sessionID: UUID, turnID: UUID, providerID: UUID, result: Result<ModelReply, Error>) {
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionID }),
              let turnIndex = sessions[sessionIndex].turns.firstIndex(where: { $0.id == turnID }),
              let answerIndex = sessions[sessionIndex].turns[turnIndex].answers.firstIndex(where: { $0.providerID == providerID }) else { return }
        switch result {
        case let .success(reply):
            sessions[sessionIndex].turns[turnIndex].answers[answerIndex].status = .finished
            sessions[sessionIndex].turns[turnIndex].answers[answerIndex].content = reply.text
            sessions[sessionIndex].turns[turnIndex].answers[answerIndex].thinkingContent = reply.thinking
            sessions[sessionIndex].turns[turnIndex].answers[answerIndex].reasoningTokenCount = reply.reasoningTokenCount
        case let .failure(error):
            sessions[sessionIndex].turns[turnIndex].answers[answerIndex].status = .failed(error.localizedDescription)
            sessions[sessionIndex].turns[turnIndex].answers[answerIndex].content = ""
            sessions[sessionIndex].turns[turnIndex].answers[answerIndex].thinkingContent = nil
            sessions[sessionIndex].turns[turnIndex].answers[answerIndex].reasoningTokenCount = nil
        }
        sessions[sessionIndex].turns[turnIndex].answers[answerIndex].finishedAt = Date()
        if turnIndex == sessions[sessionIndex].turns.indices.last {
            sessions[sessionIndex].answers = sessions[sessionIndex].turns[turnIndex].answers
        }
        sessions[sessionIndex].updatedAt = Date()
        saveSessions()
    }

    private func contextMessages(
        for provider: ProviderConfig,
        previousTurns: [ChatTurn],
        newPrompt: String
    ) -> [ChatRequestMessage] {
        var messages: [ChatRequestMessage] = []

        for turn in previousTurns {
            messages.append(ChatRequestMessage(role: "user", content: turn.prompt))
            if let answer = turn.answers.first(where: { $0.providerID == provider.id }),
               case .finished = answer.status,
               !answer.content.trimmed.isEmpty {
                messages.append(ChatRequestMessage(role: "assistant", content: answer.content))
            }
        }

        messages.append(ChatRequestMessage(role: "user", content: newPrompt))
        return messages
    }

    private func saveProviderMetadata() {
        ProviderStore.saveMetadata(providers)
    }

    private func ensureSelectedSession() -> UUID {
        if let selectedSessionID,
           sessions.contains(where: { $0.id == selectedSessionID }) {
            return selectedSessionID
        }

        let session = ChatSession()
        sessions.insert(session, at: 0)
        selectedSessionID = session.id
        return session.id
    }

    private func saveSessions() {
        ChatSessionStore.save(sessions)
    }

    private func saveFolders() {
        ChatFolderStore.save(folders)
    }

    private func showUndoDeletion(
        message: String,
        systemImage: String,
        undo: @escaping @MainActor () -> Void
    ) {
        pendingUndoTask?.cancel()
        let deletion = PendingUndoDeletion(message: message, systemImage: systemImage)
        pendingUndoDeletion = deletion
        pendingUndoHandler = undo
        pendingUndoTask = Task { [weak self, deletionID = deletion.id] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.expireUndoDeletion(id: deletionID)
            }
        }
    }

    private func clearPendingUndoDeletion() {
        pendingUndoTask?.cancel()
        pendingUndoTask = nil
        pendingUndoDeletion = nil
        pendingUndoHandler = nil
    }

    private func expireUndoDeletion(id: UUID) {
        guard pendingUndoDeletion?.id == id else { return }
        pendingUndoTask = nil
        pendingUndoDeletion = nil
        pendingUndoHandler = nil
    }

    private func isFolder(_ folderID: UUID?, descendantOf ancestorID: UUID) -> Bool {
        guard var currentID = folderID else { return false }
        while let current = folder(id: currentID) {
            if current.id == ancestorID {
                return true
            }
            guard let parentID = current.parentID else {
                return false
            }
            currentID = parentID
        }
        return false
    }

    private func descendantFolderIDs(of folderID: UUID) -> Set<UUID> {
        var result = Set<UUID>()
        var stack = childFolders(of: folderID).map(\.id)

        while let currentID = stack.popLast() {
            guard result.insert(currentID).inserted else { continue }
            stack.append(contentsOf: childFolders(of: currentID).map(\.id))
        }

        return result
    }

    private static func title(for prompt: String) -> String {
        let singleLine = prompt
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard singleLine.count > 34 else { return singleLine }
        return String(singleLine.prefix(34)) + "..."
    }

    private static func migrateArchivedSessions(_ sessions: inout [ChatSession], folders: inout [ChatFolder]) {
        normalizeInvalidFolderReferences(sessions: &sessions, folders: &folders)

        guard sessions.contains(where: { $0.isArchived }) else { return }
        let archiveFolderID: UUID
        if let existing = folders.first(where: { $0.name == "归档" || $0.name == "Archive" }) {
            archiveFolderID = existing.id
        } else {
            let archiveFolder = ChatFolder(name: "归档")
            folders.append(archiveFolder)
            archiveFolderID = archiveFolder.id
        }

        for index in sessions.indices where sessions[index].isArchived {
            if sessions[index].folderID == nil {
                sessions[index].folderID = archiveFolderID
            }
            sessions[index].isArchived = false
        }
    }

    private static func normalizeInvalidFolderReferences(sessions: inout [ChatSession], folders: inout [ChatFolder]) {
        let folderIDs = Set(folders.map(\.id))

        for index in sessions.indices {
            if let folderID = sessions[index].folderID, !folderIDs.contains(folderID) {
                sessions[index].folderID = nil
            }
        }

        for index in folders.indices {
            if let parentID = folders[index].parentID, !folderIDs.contains(parentID) {
                folders[index].parentID = nil
            }
        }

        let parentLookup = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0.parentID) })
        for index in folders.indices where hasFolderCycle(startingAt: folders[index].id, parentLookup: parentLookup) {
            folders[index].parentID = nil
        }
    }

    private static func hasFolderCycle(startingAt folderID: UUID, parentLookup: [UUID: UUID?]) -> Bool {
        var seen = Set<UUID>()
        var currentID: UUID? = folderID

        while let id = currentID, let parentID = parentLookup[id] ?? nil {
            if parentID == folderID || seen.contains(parentID) {
                return true
            }
            seen.insert(parentID)
            currentID = parentID
        }

        return false
    }
}

enum ManualUpdateStatus: Equatable {
    case idle
    case checking
    case downloading
    case upToDate(String)
    case downloaded(String)
    case failed(String)

    var isInProgress: Bool {
        switch self {
        case .checking, .downloading:
            true
        case .idle, .upToDate, .downloaded, .failed:
            false
        }
    }

    func label(language: AppLanguage) -> String? {
        switch self {
        case .idle:
            nil
        case .checking:
            language.text(.checkingUpdate)
        case .downloading:
            language.text(.downloadingUpdate)
        case let .upToDate(tag):
            "\(language.text(.alreadyLatest)) \(tag)"
        case let .downloaded(tag):
            "\(language.text(.updateDownloaded)) \(tag)"
        case let .failed(message):
            "\(language.text(.updateFailed)): \(message)"
        }
    }
}

struct PendingUndoDeletion: Identifiable, Equatable {
    let id = UUID()
    var message: String
    var systemImage: String
}
