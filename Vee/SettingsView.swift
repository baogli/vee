import Carbon
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: VeeSettings

    var body: some View {
        Form {
            Section {
                Stepper(value: $settings.visibleItemCount, in: 3...9) {
                    HStack {
                        Text("Items in popup")
                        Spacer()
                        Text("\(settings.visibleItemCount)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                Picker("Hotkey", selection: hotKeyBinding) {
                    Text("Option Command V").tag(HotKeyPreset.optionCommandV)
                    Text("Control Option V").tag(HotKeyPreset.controlOptionV)
                    Text("Shift Command V").tag(HotKeyPreset.shiftCommandV)
                }
            }

            Section {
                Text("Vee ignores concealed pasteboard content and only stores text locally in memory for this MVP.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 420)
    }

    private var hotKeyBinding: Binding<HotKeyPreset> {
        Binding {
            HotKeyPreset(
                keyCode: settings.hotKeyKeyCode,
                modifiers: settings.hotKeyModifiers
            ) ?? .optionCommandV
        } set: { preset in
            settings.hotKeyKeyCode = preset.keyCode
            settings.hotKeyModifiers = preset.modifiers
        }
    }
}

enum HotKeyPreset: Hashable {
    case optionCommandV
    case controlOptionV
    case shiftCommandV

    init?(keyCode: UInt32, modifiers: UInt32) {
        switch (keyCode, modifiers) {
        case (UInt32(kVK_ANSI_V), UInt32(cmdKey | optionKey)):
            self = .optionCommandV
        case (UInt32(kVK_ANSI_V), UInt32(controlKey | optionKey)):
            self = .controlOptionV
        case (UInt32(kVK_ANSI_V), UInt32(cmdKey | shiftKey)):
            self = .shiftCommandV
        default:
            return nil
        }
    }

    var keyCode: UInt32 {
        UInt32(kVK_ANSI_V)
    }

    var modifiers: UInt32 {
        switch self {
        case .optionCommandV:
            return UInt32(cmdKey | optionKey)
        case .controlOptionV:
            return UInt32(controlKey | optionKey)
        case .shiftCommandV:
            return UInt32(cmdKey | shiftKey)
        }
    }
}
