import AppKit
import Carbon
import Combine
import SwiftUI

@MainActor
final class VeeSettings: ObservableObject {
    @AppStorage("visibleItemCount") var visibleItemCount = 5 {
        willSet { objectWillChange.send() }
    }

    @AppStorage("hotKeyKeyCode") private var storedHotKeyKeyCode = Int(kVK_ANSI_V) {
        willSet { objectWillChange.send() }
    }

    @AppStorage("hotKeyModifiers") private var storedHotKeyModifiers = Int(cmdKey | optionKey) {
        willSet { objectWillChange.send() }
    }

    var hotKeyKeyCode: UInt32 {
        get { UInt32(storedHotKeyKeyCode) }
        set {
            objectWillChange.send()
            storedHotKeyKeyCode = Int(newValue)
        }
    }

    var hotKeyModifiers: UInt32 {
        get { UInt32(storedHotKeyModifiers) }
        set {
            objectWillChange.send()
            storedHotKeyModifiers = Int(newValue)
        }
    }
}

@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?
    private let maxItems = 60

    init() {
        lastChangeCount = pasteboard.changeCount
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        guard pasteboard.changeCount != lastChangeCount else {
            return
        }

        lastChangeCount = pasteboard.changeCount

        guard !pasteboard.containsConcealedContent,
              let string = pasteboard.string(forType: .string),
              !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        add(string)
    }

    private func add(_ string: String) {
        items.removeAll { $0.content == string }
        items.insert(ClipboardItem(content: string, copiedAt: Date()), at: 0)

        if items.count > maxItems {
            items.removeLast(items.count - maxItems)
        }
    }
}

private extension NSPasteboard {
    var containsConcealedContent: Bool {
        let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

        if types?.contains(concealedType) == true {
            return true
        }

        return pasteboardItems?.contains { item in
            item.types.contains(concealedType)
        } == true
    }
}
