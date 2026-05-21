import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct ModelRoomApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("ModelRoom") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 1040, minHeight: 700)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button(model.language.text(.newChat)) {
                    model.newChat()
                }
                .keyboardShortcut("n", modifiers: [.command])
            }

            CommandGroup(replacing: .appSettings) {
                Button(model.language.text(.settingsMenu)) {
                    SettingsWindowPresenter.show(model: model)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
        }
    }
}
