import AppKit

struct Shortcut: Codable, Equatable {
    let keyCode: UInt16
    let modifiers: UInt
    let display: String

    static let `default` = Shortcut(
        keyCode: 42,
        modifiers: NSEvent.ModifierFlags([.control, .shift]).rawValue,
        display: "⌃⇧|"
    )

    func matches(_ event: NSEvent) -> Bool {
        let active = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .intersection([.command, .control, .option, .shift])
        return event.type == .keyDown && event.keyCode == keyCode && active == NSEvent.ModifierFlags(rawValue: modifiers)
    }
}

enum ShortcutStore {
    static let shortcutDidChange = Notification.Name("ChoiceLensShortcutDidChange")
    private static let key = "scanShortcut"

    static func current() -> Shortcut {
        guard let data = UserDefaults.standard.data(forKey: key),
              let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data)
        else { return .default }
        return shortcut
    }

    static func save(_ shortcut: Shortcut) {
        guard let data = try? JSONEncoder().encode(shortcut) else { return }
        UserDefaults.standard.set(data, forKey: key)
        NotificationCenter.default.post(name: shortcutDidChange, object: nil)
    }

    static func displayName(for event: NSEvent) -> String {
        let modifiers = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .intersection([.command, .control, .option, .shift])
        let modifierText = [
            modifiers.contains(.control) ? "⌃" : "",
            modifiers.contains(.option) ? "⌥" : "",
            modifiers.contains(.shift) ? "⇧" : "",
            modifiers.contains(.command) ? "⌘" : ""
        ].joined()
        let keyText = event.keyCode == 42 && modifiers.contains(.shift)
            ? "|"
            : (event.charactersIgnoringModifiers ?? "?").uppercased()
        return modifierText + keyText
    }
}
