import AppKit
import ApplicationServices
import Carbon
import os.log

@MainActor
final class PasteboardInjector {
    private let pasteboard = NSPasteboard.general
    private let log = Logger(subsystem: "com.vee.app", category: "paste")

    func paste(_ string: String, into targetApplication: NSRunningApplication?) {
        VeeLog.write("paste: AXTrusted=\(AXIsProcessTrusted())")

        guard AXIsProcessTrusted() else {
            // Without Accessibility trust the synthetic Cmd-V is silently
            // dropped, so surface the problem instead of failing quietly.
            log.error("Paste blocked: process is not trusted for Accessibility")
            NSSound.beep()
            openAccessibilitySettings()
            return
        }

        log.info("Pasting \(string.count, privacy: .public) characters")
        let snapshot = PasteboardSnapshot.capture(from: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)

        if let targetApplication, !targetApplication.isTerminated {
            let activated = targetApplication.activate(options: [])
            VeeLog.write("target activate: \(targetApplication.localizedName ?? "?"), ok=\(activated)")
        }

        // Give the pasteboard server a beat to publish the new contents
        // before the target app reads it in response to Command-V.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            VeeLog.write("sending Cmd-V, frontmost=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "?")")
            self.sendCommandV(to: targetApplication?.processIdentifier)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            snapshot.restore(to: self.pasteboard)
        }
    }

    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func sendCommandV(to processIdentifier: pid_t?) {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        if let processIdentifier {
            keyDown?.postToPid(processIdentifier)
            keyUp?.postToPid(processIdentifier)
        } else {
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        }
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
