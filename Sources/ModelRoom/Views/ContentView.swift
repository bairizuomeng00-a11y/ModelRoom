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
        .animation(.spring(response: 0.24, dampingFraction: 0.86), value: isSidebarVisible)
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
