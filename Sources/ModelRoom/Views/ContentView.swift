import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isSidebarVisible = true

    var body: some View {
        HSplitView {
            if isSidebarVisible {
                SidebarView()
                    .frame(minWidth: 180, idealWidth: 205, maxWidth: 245)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            ConversationView()
                .frame(minWidth: 480)
        }
        .background(WindowTransparencyConfigurator())
        .animation(.spring(response: 0.24, dampingFraction: 0.86), value: isSidebarVisible)
        .overlay(alignment: .bottom) {
            UndoDeletionToastView()
        }
        .animation(.spring(response: 0.22, dampingFraction: 0.84), value: model.pendingUndoDeletion?.id)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    isSidebarVisible.toggle()
                } label: {
                    Label(model.language.text(.toggleSidebar), systemImage: "sidebar.left")
                }
                .help(model.language.text(.toggleSidebar))

                Button {
                    model.newChat()
                } label: {
                    Label(model.language.text(.newChat), systemImage: "square.and.pencil")
                }

                Button {
                    model.newFolder()
                } label: {
                    Label(model.language.text(.newFolder), systemImage: "folder.badge.plus")
                }

                Button(role: .destructive) {
                    model.deleteSelectedChat()
                } label: {
                    Label(model.language.text(.deleteChat), systemImage: "trash")
                }
                .disabled(model.selectedSession == nil)

                Button {
                    SettingsWindowPresenter.show(model: model)
                } label: {
                    Label(model.language.text(.settings), systemImage: "gearshape")
                }
            }
        }
    }
}

private struct WindowTransparencyConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: view.window)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
    }
}
