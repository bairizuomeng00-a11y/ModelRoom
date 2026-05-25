import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @EnvironmentObject private var model: AppModel
    @State private var expandedFolderIDs: Set<UUID> = []
    @State private var isRootTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section(model.language.text(.folders)) {
                    RootDropRow(
                        title: model.language.text(.activeChats),
                        detail: "\(model.itemCount(in: nil))",
                        isTargeted: isRootTargeted
                    )
                    .onDrop(of: [UTType.plainText.identifier], isTargeted: $isRootTargeted) { providers in
                        handleDrop(providers: providers, destinationFolderID: nil)
                    }
                    .contextMenu {
                        Button(model.language.text(.newFolder)) {
                            model.newFolder()
                        }
                    }

                    ForEach(model.rootFolders) { folder in
                        FolderNodeView(
                            folder: folder,
                            level: 0,
                            expandedFolderIDs: $expandedFolderIDs
                        )
                    }
                }

                if !model.rootSessions.isEmpty {
                    Section(model.language.text(.chats)) {
                        ForEach(model.rootSessions) { session in
                            ChatRow(
                                session: session,
                                language: model.language,
                                level: 0,
                                isSelected: model.selectedSessionID == session.id
                            )
                                .onTapGesture {
                                    model.selectedSessionID = session.id
                                }
                                .onDrag {
                                    NSItemProvider(object: SidebarDropItem.session(session.id).payload as NSString)
                                }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            HStack(spacing: 10) {
                Label(model.language.modelsReady(model.runnableProviders.count), systemImage: "cpu")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(SidebarBackground())
    }

    private func handleDrop(providers: [NSItemProvider], destinationFolderID: UUID?) -> Bool {
        var didHandle = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                guard let dropItem = SidebarDropItemDecoder.item(from: item) else { return }
                Task { @MainActor in
                    switch dropItem {
                    case let .session(id):
                        model.moveSession(id, to: destinationFolderID)
                    case let .folder(id):
                        model.moveFolder(id, to: destinationFolderID)
                    }
                }
            }
            didHandle = true
        }
        return didHandle
    }
}

private struct SidebarBackground: View {
    var body: some View {
        ZStack {
            SidebarVisualEffectView()

            LinearGradient(
                colors: [
                    Color.white.opacity(0.10),
                    Color(nsColor: .controlBackgroundColor).opacity(0.045),
                    Color.black.opacity(0.010)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.plusLighter)

            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.026),
                    Color.cyan.opacity(0.016),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottom
            )
            .blendMode(.plusLighter)
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.36),
                            .black.opacity(0.020)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 1)
        }
    }
}

private struct SidebarVisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = false
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = false
    }
}

private struct FolderNodeView: View {
    @EnvironmentObject private var model: AppModel
    var folder: ChatFolder
    var level: Int
    @Binding var expandedFolderIDs: Set<UUID>
    @State private var isTargeted = false

    private var isExpanded: Bool {
        expandedFolderIDs.contains(folder.id)
    }

    var body: some View {
        FolderRow(
            folder: folder,
            level: level,
            isExpanded: isExpanded,
            isTargeted: isTargeted,
            name: Binding(
                get: { model.folder(id: folder.id)?.name ?? folder.name },
                set: { model.renameFolder(id: folder.id, name: $0) }
            ),
            itemCount: model.itemCount(in: folder.id),
            toggle: toggle
        )
        .onDrag {
            NSItemProvider(object: SidebarDropItem.folder(folder.id).payload as NSString)
        }
        .onDrop(of: [UTType.plainText.identifier], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
        .contextMenu {
            Button(model.language.text(.newFolder)) {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                    _ = expandedFolderIDs.insert(folder.id)
                }
                model.newFolder(parentID: folder.id)
            }

            Button(model.language.text(.activeChats)) {
                model.moveFolder(folder.id, to: nil)
            }
            .disabled(folder.parentID == nil)

            Button(role: .destructive) {
                model.deleteFolder(folder.id)
            } label: {
                Label(model.language.text(.deleteFolder), systemImage: "trash")
            }
        }

        if isExpanded {
            ForEach(model.childFolders(of: folder.id)) { child in
                FolderNodeView(
                    folder: child,
                    level: level + 1,
                    expandedFolderIDs: $expandedFolderIDs
                )
            }

            ForEach(model.sessions(in: folder.id)) { session in
                ChatRow(
                    session: session,
                    language: model.language,
                    level: level + 1,
                    isSelected: model.selectedSessionID == session.id
                )
                    .onTapGesture {
                        model.selectedSessionID = session.id
                    }
                    .onDrag {
                        NSItemProvider(object: SidebarDropItem.session(session.id).payload as NSString)
                    }
                    .contextMenu {
                        Button(model.language.text(.activeChats)) {
                            model.moveSession(session.id, to: nil)
                        }
                    }
            }
        }
    }

    private func toggle() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            if isExpanded {
                expandedFolderIDs.remove(folder.id)
            } else {
                expandedFolderIDs.insert(folder.id)
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var didHandle = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                guard let dropItem = SidebarDropItemDecoder.item(from: item) else { return }
                Task { @MainActor in
                    switch dropItem {
                    case let .session(id):
                        model.moveSession(id, to: folder.id)
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                            _ = expandedFolderIDs.insert(folder.id)
                        }
                    case let .folder(id):
                        model.moveFolder(id, to: folder.id)
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                            _ = expandedFolderIDs.insert(folder.id)
                        }
                    }
                }
            }
            didHandle = true
        }
        return didHandle
    }
}

private struct RootDropRow: View {
    var title: String
    var detail: String
    var isTargeted: Bool
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "tray")
                .foregroundStyle(isActive ? .primary : .secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .lineLimit(1)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 2)
        .glassRowBackground(isActive: isActive)
        .listRowBackground(Color.clear)
        .scaleEffect(isTargeted ? 1.01 : 1)
        .onHover { isHovering = $0 }
    }

    private var isActive: Bool {
        isTargeted || isHovering
    }
}

private struct FolderRow: View {
    var folder: ChatFolder
    var level: Int
    var isExpanded: Bool
    var isTargeted: Bool
    @Binding var name: String
    var itemCount: Int
    var toggle: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 5) {
            Button(action: toggle) {
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 20, height: 24)

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .frame(width: 12)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Image(systemName: isExpanded ? "folder.fill" : "folder")
                .foregroundStyle(isActive ? .primary : .secondary)
                .frame(width: 16)

            TextField("", text: $name)
                .textFieldStyle(.plain)
                .lineLimit(1)

            Spacer(minLength: 4)

            Text("\(itemCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.leading, CGFloat(level) * 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 2)
        .glassRowBackground(isActive: isActive)
        .listRowBackground(Color.clear)
        .scaleEffect(isTargeted ? 1.01 : 1)
        .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isExpanded)
        .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isTargeted)
        .onHover { isHovering = $0 }
    }

    private var isActive: Bool {
        isTargeted || isHovering
    }
}

private struct ChatRow: View {
    var session: ChatSession
    var language: AppLanguage
    var level: Int
    var isSelected: Bool
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: session.prompt.isEmpty ? "bubble.left" : "bubble.left.and.text.bubble.right")
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.title.isEmpty ? language.text(.newChatTitle) : session.title)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)

                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.primary.opacity(0.68) : Color.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.leading, CGFloat(level) * 14 + (isSelected ? 12 : 7))
        .padding(.trailing, isSelected ? 10 : 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 2)
        .glassRowBackground(isActive: isSelected || isHovering, isSelected: isSelected)
        .listRowBackground(Color.clear)
        .scaleEffect(isHovering ? 1.005 : 1)
        .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isSelected)
        .onHover { isHovering = $0 }
    }

    private var detailText: String {
        let answerCount = session.turns.reduce(0) { $0 + $1.answers.count }
        if answerCount == 0 {
            return language.text(.noAnswersYet)
        }
        return language.modelAnswers(answerCount)
    }
}

private enum SidebarDropItem: Equatable {
    case session(UUID)
    case folder(UUID)

    var payload: String {
        switch self {
        case let .session(id):
            "session:\(id.uuidString)"
        case let .folder(id):
            "folder:\(id.uuidString)"
        }
    }
}

private enum SidebarDropItemDecoder {
    static func item(from item: NSSecureCoding?) -> SidebarDropItem? {
        guard let text = text(from: item) else { return nil }

        if let id = id(afterPrefix: "session:", in: text) {
            return .session(id)
        }
        if let id = id(afterPrefix: "folder:", in: text) {
            return .folder(id)
        }
        if let id = UUID(uuidString: text) {
            return .session(id)
        }
        return nil
    }

    private static func text(from item: NSSecureCoding?) -> String? {
        if let text = item as? String {
            return text
        }
        if let text = item as? NSString {
            return text as String
        }
        if let data = item as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    private static func id(afterPrefix prefix: String, in text: String) -> UUID? {
        guard text.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(text.dropFirst(prefix.count)))
    }
}
