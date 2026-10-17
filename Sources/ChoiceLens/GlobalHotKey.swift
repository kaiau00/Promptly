import AppKit
import Carbon

/// Registers a macOS system hotkey. Unlike an event monitor, this does not need
/// Input Monitoring permission and never takes focus away from the frontmost app.
final class GlobalHotKey: NSObject {
    private let action: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init(action: @escaping () -> Void) {
        self.action = action
        super.init()
        installHandler()
        registerCurrentShortcut()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(shortcutDidChange),
            name: ShortcutStore.shortcutDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        unregisterCurrentShortcut()
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
    }

    @objc private func shortcutDidChange() {
        unregisterCurrentShortcut()
        registerCurrentShortcut()
    }

    @objc private func invokeAction() {
        action()
    }

    private func installHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetEventDispatcherTarget(),
            Self.hotKeyPressed,
            1,
            &eventType,
            userData,
            &eventHandlerRef
        )
    }

    private func registerCurrentShortcut() {
        let shortcut = ShortcutStore.current()
        let identifier = EventHotKeyID(signature: OSType(0x434C454E), id: 1) // "CLEN"
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            carbonModifiers(for: shortcut.modifiers),
            identifier,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr { hotKeyRef = nil }
    }

    private func unregisterCurrentShortcut() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func carbonModifiers(for rawValue: UInt) -> UInt32 {
        let modifiers = NSEvent.ModifierFlags(rawValue: rawValue)
        var result: UInt32 = 0
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    private static let hotKeyPressed: EventHandlerUPP = { _, _, userData in
        guard let userData else { return noErr }
        let owner = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
        owner.performSelector(onMainThread: #selector(GlobalHotKey.invokeAction), with: nil, waitUntilDone: false)
        return noErr
    }
}
