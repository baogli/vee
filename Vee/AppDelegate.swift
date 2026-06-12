import AppKit
import ApplicationServices
import Carbon
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = VeeSettings()

    private let store = ClipboardStore()
    private let hotKeyManager = HotKeyManager()
    private var popupController: PopupPanelController?
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        requestAccessibilityIfNeeded()

        popupController = PopupPanelController(store: store, settings: settings)
        store.start()
        installStatusItem()
        registerHotKey()

        settings.objectWillChange
            .debounce(for: .milliseconds(80), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.registerHotKey()
            }
            .store(in: &cancellables)
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stop()
        hotKeyManager.unregister()
    }

    private func registerHotKey() {
        hotKeyManager.register(
            keyCode: settings.hotKeyKeyCode,
            modifiers: settings.hotKeyModifiers
        ) { [weak self] in
            Task { @MainActor in
                self?.popupController?.toggle()
            }
        }
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Vee")

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Vee", action: #selector(showVee), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Fix Accessibility...", action: #selector(fixAccessibility), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Vee", action: #selector(quit), keyEquivalent: "q"))

        item.menu = menu
        statusItem = item
    }

    @objc private func showVee() {
        popupController?.toggle()
    }

    @objc private func openSettings() {
        // sendAction(showSettingsWindow:) is unreliable for accessory apps,
        // so Vee manages its own settings window.
        if settingsWindow == nil {
            let hosting = NSHostingController(
                rootView: SettingsView().environmentObject(settings)
            )
            let window = NSWindow(contentViewController: hosting)
            window.title = "Vee Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }

        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func requestAccessibilityIfNeeded() {
        // Without Accessibility trust, the synthetic Command-V is silently
        // dropped and caret positioning falls back to the mouse.
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func fixAccessibility() {
        // The system prompt adds Vee to the Accessibility list by itself;
        // the user only has to flip the toggle. No file dialogs, no paths.
        requestAccessibilityIfNeeded()

        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
