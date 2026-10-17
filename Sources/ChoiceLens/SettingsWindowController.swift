import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
    var onAPIKeySaved: ((String) -> Void)?
    private let apiKeyField = NSSecureTextField()
    private let statusLabel = NSTextField(labelWithString: "")
    private let saveButton = NSButton(title: "Save securely", target: nil, action: nil)
    private let replaceButton = NSButton(title: "Replace key…", target: nil, action: nil)
    private let shortcutValueLabel = NSTextField(labelWithString: "")
    private let changeShortcutButton = NSButton(title: "Change shortcut…", target: nil, action: nil)
    private var shortcutMonitor: Any?
    private var hasSavedKey = false

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 335),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Promptly Settings"
        window.isReleasedWhenClosed = false
        super.init(window: window)

        let content = NSView()
        window.contentView = content

        let title = NSTextField(labelWithString: "MiniMax API key")
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(title)

        apiKeyField.placeholderString = "Paste an API key"
        apiKeyField.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(apiKeyField)

        let detail = NSTextField(wrappingLabelWithString: "The key is saved only in your macOS Keychain. Each scan sends recognized text—not a screenshot—to MiniMax for analysis.")
        detail.textColor = .secondaryLabelColor
        detail.font = .systemFont(ofSize: 12)
        detail.maximumNumberOfLines = 3
        detail.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(detail)

        saveButton.target = self
        saveButton.action = #selector(save)
        saveButton.bezelStyle = .rounded
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(saveButton)

        replaceButton.target = self
        replaceButton.action = #selector(beginReplacingKey)
        replaceButton.bezelStyle = .rounded
        replaceButton.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(replaceButton)

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(statusLabel)

        let shortcutTitle = NSTextField(labelWithString: "Scan shortcut")
        shortcutTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        shortcutTitle.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(shortcutTitle)

        shortcutValueLabel.font = .monospacedSystemFont(ofSize: 14, weight: .medium)
        shortcutValueLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(shortcutValueLabel)

        changeShortcutButton.target = self
        changeShortcutButton.action = #selector(beginRecordingShortcut)
        changeShortcutButton.bezelStyle = .rounded
        changeShortcutButton.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(changeShortcutButton)

        let shortcutHelp = NSTextField(wrappingLabelWithString: "Choose any combination with Command, Control, Option, or Shift. It is saved locally and works immediately.")
        shortcutHelp.textColor = .secondaryLabelColor
        shortcutHelp.font = .systemFont(ofSize: 12)
        shortcutHelp.maximumNumberOfLines = 2
        shortcutHelp.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(shortcutHelp)

        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            title.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            title.topAnchor.constraint(equalTo: content.topAnchor, constant: 25),
            apiKeyField.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            apiKeyField.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            apiKeyField.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 10),
            detail.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            detail.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            detail.topAnchor.constraint(equalTo: apiKeyField.bottomAnchor, constant: 12),
            saveButton.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            saveButton.topAnchor.constraint(equalTo: detail.bottomAnchor, constant: 17),
            replaceButton.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            replaceButton.topAnchor.constraint(equalTo: detail.bottomAnchor, constant: 17),
            statusLabel.leadingAnchor.constraint(equalTo: saveButton.trailingAnchor, constant: 12),
            statusLabel.centerYAnchor.constraint(equalTo: saveButton.centerYAnchor),
            shortcutTitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            shortcutTitle.topAnchor.constraint(equalTo: saveButton.bottomAnchor, constant: 31),
            shortcutValueLabel.leadingAnchor.constraint(equalTo: shortcutTitle.leadingAnchor),
            shortcutValueLabel.topAnchor.constraint(equalTo: shortcutTitle.bottomAnchor, constant: 10),
            changeShortcutButton.leadingAnchor.constraint(equalTo: shortcutValueLabel.trailingAnchor, constant: 14),
            changeShortcutButton.centerYAnchor.constraint(equalTo: shortcutValueLabel.centerYAnchor),
            shortcutHelp.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            shortcutHelp.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            shortcutHelp.topAnchor.constraint(equalTo: shortcutValueLabel.bottomAnchor, constant: 11)
        ])

        hasSavedKey = (try? KeychainStore.loadAPIKey()) != nil
        updateKeyState()
    }

    required init?(coder: NSCoder) { nil }

    func present() {
        hasSavedKey = (try? KeychainStore.loadAPIKey()) != nil
        updateKeyState()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func save() {
        let key = apiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            statusLabel.stringValue = "Paste a key to save it."
            statusLabel.textColor = .systemRed
            return
        }
        do {
            try KeychainStore.saveAPIKey(key)
            onAPIKeySaved?(key)
            apiKeyField.stringValue = ""
            hasSavedKey = true
            updateKeyState(message: "Replacement saved in Keychain")
        } catch {
            statusLabel.stringValue = error.localizedDescription
            statusLabel.textColor = .systemRed
        }
    }

    @objc private func beginReplacingKey() {
        hasSavedKey = false
        apiKeyField.stringValue = ""
        updateKeyState()
        window?.makeFirstResponder(apiKeyField)
    }

    private func updateKeyState(message: String? = nil) {
        apiKeyField.isHidden = hasSavedKey
        saveButton.isHidden = hasSavedKey
        replaceButton.isHidden = !hasSavedKey

        if hasSavedKey {
            statusLabel.stringValue = message ?? "MiniMax key: Set"
            statusLabel.textColor = .systemGreen
        } else {
            apiKeyField.placeholderString = "Paste a MiniMax API key"
            statusLabel.stringValue = "MiniMax key: Not set"
            statusLabel.textColor = .secondaryLabelColor
        }
        shortcutValueLabel.stringValue = ShortcutStore.current().display
    }

    @objc private func beginRecordingShortcut() {
        if let shortcutMonitor { NSEvent.removeMonitor(shortcutMonitor) }
        shortcutValueLabel.stringValue = "Press a shortcut…"
        changeShortcutButton.title = "Listening…"
        shortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in self?.recordShortcut(event) }
            return nil
        }
        window?.makeKeyAndOrderFront(nil)
    }

    private func recordShortcut(_ event: NSEvent) {
        let modifiers = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .intersection([.command, .control, .option, .shift])
        guard !modifiers.isEmpty else {
            shortcutValueLabel.stringValue = "Use at least one modifier"
            return
        }
        if let shortcutMonitor { NSEvent.removeMonitor(shortcutMonitor) }
        shortcutMonitor = nil
        let shortcut = Shortcut(keyCode: event.keyCode, modifiers: modifiers.rawValue, display: ShortcutStore.displayName(for: event))
        ShortcutStore.save(shortcut)
        shortcutValueLabel.stringValue = shortcut.display
        changeShortcutButton.title = "Change shortcut…"
    }
}
