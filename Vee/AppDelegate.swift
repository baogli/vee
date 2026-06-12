import AppKit
import Carbon
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = VeeSettings()

    private let store = ClipboardStore()
    private let hotKeyManager = HotKeyManager()
    private var popupController: PopupPanelController?
    private var statusItem: NSStatusItem?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

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
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Vee", action: #selector(quit), keyEquivalent: "q"))

        item.menu = menu
        statusItem = item
    }

    @objc private func showVee() {
        popupController?.toggle()
    }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
