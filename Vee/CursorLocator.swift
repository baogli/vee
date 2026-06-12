import AppKit
import ApplicationServices

enum CursorLocator {
    static func insertionPointScreenRect() -> CGRect? {
        guard AXIsProcessTrusted() else {
            return nil
        }

        guard let focusedElement = focusedUIElement(),
              let selectedRange = selectedTextRange(in: focusedElement),
              let bounds = bounds(for: selectedRange, in: focusedElement),
              bounds.width.isFinite,
              bounds.height.isFinite else {
            return nil
        }

        return bounds
    }

    static func fallbackMouseRect() -> CGRect {
        let location = NSEvent.mouseLocation
        return CGRect(x: location.x, y: location.y, width: 1, height: 1)
    }

    private static func focusedUIElement() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let applicationElement = AXUIElementCreateApplication(app.processIdentifier)
        var focused: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            applicationElement,
            kAXFocusedUIElementAttribute as CFString,
            &focused
        )

        guard result == .success else {
            return nil
        }

        return (focused as AnyObject) as! AXUIElement?
    }

    private static func selectedTextRange(in element: AXUIElement) -> AXValue? {
        var selectedRange: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRange
        )

        guard result == .success else {
            return nil
        }

        return selectedRange as! AXValue?
    }

    private static func bounds(for selectedRange: AXValue, in element: AXUIElement) -> CGRect? {
        var boundsValue: CFTypeRef?
        let parameterizedResult = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            selectedRange,
            &boundsValue
        )

        guard parameterizedResult == .success,
              let boundsValue else {
            return nil
        }

        let value = boundsValue as! AXValue
        var rect = CGRect.zero
        guard AXValueGetValue(value, .cgRect, &rect) else {
            return nil
        }

        return rect
    }
}
