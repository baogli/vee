import AppKit
import Carbon
import SwiftUI

@MainActor
final class PopupPanelController {
    private let store: ClipboardStore
    private let settings: VeeSettings
    private let injector = PasteboardInjector()
    private var panel: VeePanel?
    private var eventMonitor: Any?
    private var globalMouseMonitor: Any?

    init(store: ClipboardStore, settings: VeeSettings) {
        self.store = store
        self.settings = settings
    }

    func toggle() {
        if panel?.isVisible == true {
            close()
        } else {
            show()
        }
    }

    func show() {
        guard !store.items.isEmpty else {
            return
        }

        close()

        let viewModel = PopupViewModel(
            items: store.items,
            visibleCount: max(3, min(settings.visibleItemCount, 9)),
            select: { [weak self] item in
                self?.choose(item)
            },
            close: { [weak self] in
                self?.close()
            }
        )

        let content = PopupView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: content)
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 520, height: 320)

        let panel = VeePanel(
            contentRect: hostingController.view.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.contentViewController = hostingController
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.animationBehavior = .none
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        self.panel = panel
        resizeAndPosition(panel, fitting: hostingController)
        installEventMonitor(viewModel: viewModel)
    }

    func close() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }

        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }

        if let closing = panel {
            panel = nil
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.12
                closing.animator().alphaValue = 0
            }, completionHandler: {
                Task { @MainActor in
                    closing.orderOut(nil)
                }
            })
        }
    }

    private func choose(_ item: ClipboardItem) {
        close()
        injector.paste(item.content)
    }

    private func resizeAndPosition(_ panel: NSPanel, fitting hostingController: NSHostingController<PopupView>) {
        let targetSize = hostingController.sizeThatFits(in: NSSize(width: 520, height: 900))
        let size = NSSize(width: min(max(targetSize.width, 360), 520), height: targetSize.height)
        let anchor = CursorLocator.insertionPointScreenRect() ?? CursorLocator.fallbackMouseRect()
        let screen = NSScreen.screens.first { $0.frame.contains(anchor.origin) } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let padding: CGFloat = 10

        var origin = CGPoint(x: anchor.minX, y: anchor.minY - size.height - 8)

        if origin.x + size.width > visibleFrame.maxX - padding {
            origin.x = visibleFrame.maxX - size.width - padding
        }

        if origin.x < visibleFrame.minX + padding {
            origin.x = visibleFrame.minX + padding
        }

        if origin.y < visibleFrame.minY + padding {
            origin.y = anchor.maxY + 8
        }

        if origin.y + size.height > visibleFrame.maxY - padding {
            origin.y = visibleFrame.maxY - size.height - padding
        }

        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    private func installEventMonitor(viewModel: PopupViewModel) {
        // Clicks in other apps never reach a local monitor, so a global one
        // is required to dismiss the non-activating panel on outside clicks.
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            self?.close()
        }

        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self, weak viewModel] event in
            guard let self, let viewModel else {
                return event
            }

            if event.type != .keyDown {
                if event.window !== self.panel {
                    self.close()
                }
                return event
            }

            switch event.keyCode {
            case UInt16(kVK_Escape):
                self.close()
                return nil
            case UInt16(kVK_Return), UInt16(kVK_ANSI_KeypadEnter):
                viewModel.chooseSelected()
                return nil
            case UInt16(kVK_UpArrow):
                viewModel.moveSelection(-1)
                return nil
            case UInt16(kVK_DownArrow):
                viewModel.moveSelection(1)
                return nil
            default:
                if let number = Int(event.charactersIgnoringModifiers ?? ""),
                   number >= 1,
                   number <= viewModel.visibleItems.count {
                    viewModel.choose(index: number - 1)
                    return nil
                }

                return event
            }
        }
    }
}

final class VeePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
