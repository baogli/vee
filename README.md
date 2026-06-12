# Vee

Vee is a tiny macOS clipboard tail that appears where you are typing.

`Command-C` and `Command-V` keep working exactly as they do today. Press `Option-Command-V`, pick one of the latest clipboard items with a number key, or press `Return` to paste the selected item.

## Why

Most clipboard managers open from the menu bar and ask you to manage a library. Vee is deliberately smaller: it shows the recent tail of your clipboard beside the text cursor, then gets out of the way.

That is the whole product:

> Copy and paste stay normal. Option-Command-V shows the last N items at the cursor. A number or Return pastes.

## MVP

- Non-activating `NSPanel`, so focus stays in the app where you are typing.
- Liquid Glass on macOS 26 via SwiftUI `glassEffect`.
- Native material fallback on older macOS versions.
- Cursor positioning through Accessibility bounds for the selected text range.
- Mouse-position fallback for apps that report unreliable caret bounds.
- Paste by temporarily writing the selected item to the system pasteboard, sending `Command-V`, then restoring the previous pasteboard contents.
- Clipboard monitoring by polling `NSPasteboard.changeCount` every 0.3 seconds.
- Concealed pasteboard content is ignored through `org.nspasteboard.ConcealedType`.
- Two settings: visible item count and hotkey preset.
- A small `More history` affordance reveals the rest of the in-memory tail without turning the app into a search-and-pin manager.

## Controls

- `Option-Command-V`: show or hide Vee.
- `1`-`9`: paste the visible item.
- `Return`: paste the selected item.
- `Up` / `Down`: move selection.
- `Escape`: close.

## Permissions

Vee needs Accessibility permission for two things:

1. Reading the text cursor bounds so the panel can appear where you are typing.
2. Sending the synthetic paste shortcut after a selection.

If the focused app does not expose reliable cursor bounds, Vee falls back to the mouse cursor.

## Build

Open `Vee.xcodeproj` in Xcode 26 or newer and run the `Vee` target.

The deployment target is macOS 14. Liquid Glass is used automatically when the app is built and run on macOS 26 or newer.

## Positioning

Maccy is the best mental comparison: minimal, fast, open source. Vee's difference is placement. It appears where you are typing, not up in the menu bar.
