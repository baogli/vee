import AppKit
import Carbon

@MainActor
final class PasteboardInjector {
    private let pasteboard = NSPasteboard.general

    func paste(_ string: String) {
        let snapshot = PasteboardSnapshot.capture(from: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)

        // Give the pasteboard server a beat to publish the new contents
        // before the target app reads it in response to Command-V.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            self.sendCommandV()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            snapshot.restore(to: self.pasteboard)
        }
    }

    private func sendCommandV() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

private struct PasteboardSnapshot {
    let items: [NSPasteboardItem]

    static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let copiedItems: [NSPasteboardItem] = pasteboard.pasteboardItems?.map { item in
            let copy = NSPasteboardItem()

            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }

            return copy
        } ?? []

        return PasteboardSnapshot(items: copiedItems)
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()

        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }
}
