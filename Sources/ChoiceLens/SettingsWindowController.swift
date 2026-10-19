import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
    var onAPIKeySaved: ((AIProvider, String) -> Void)?

    private let providerPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let apiKeyTitle = NSTextField(labelWithString: "")
    private let apiKeyField = NSSecureTextField()
    private let detail = NSTextField(wrappingLabelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let saveButton = NSButton(title: "Save securely", target: nil, action: nil)
    private let replaceButton = NSButton(title: "Replace key…", target: nil, action: nil)
    private let shortcutValueLabel = NSTextField(labelWithString: "")
    private let changeShortcutButton = NSButton(title: "Change shortcut…", target: nil, action: nil)
    private var shortcutMonitor: Any?
    private var hasSavedKey = false

    private var provider: AIProvider { ProviderStore.current }

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Promptly Settings"
        window.isReleasedWhenClosed = false
        super.init(window: window)

        let content = NSView()
        window.contentView = content

        let providerTitle = NSTextField(labelWithString: "AI provider")
        providerTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        providerTitle.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(providerTitle)

        providerPopup.addItems(withTitles: AIProvider.allCases.map(\.displayName))
        providerPopup.selectItem(withTitle: provider.displayName)
        providerPopup.target = self
        providerPopup.action = #selector(providerDidChange)
        providerPopup.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(providerPopup)

        apiKeyTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        apiKeyTitle.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(apiKeyTitle)

        apiKeyField.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(apiKeyField)

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
            providerTitle.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            providerTitle.topAnchor.constraint(equalTo: content.topAnchor, constant: 25),
            providerPopup.leadingAnchor.constraint(equalTo: providerTitle.leadingAnchor),
            providerPopup.topAnchor.constraint(equalTo: providerTitle.bottomAnchor, constant: 8),
            apiKeyTitle.leadingAnchor.constraint(equalTo: providerTitle.leadingAnchor),
            apiKeyTitle.topAnchor.constraint(equalTo: providerPopup.bottomAnchor, constant: 22),
            apiKeyField.leadingAnchor.constraint(equalTo: providerTitle.leadingAnchor),
            apiKeyField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            apiKeyField.topAnchor.constraint(equalTo: apiKeyTitle.bottomAnchor, constant: 10),
            detail.leadingAnchor.constraint(equalTo: providerTitle.leadingAnchor),
            detail.trailingAnchor.constraint(equalTo: apiKeyField.trailingAnchor),
            detail.topAnchor.constraint(equalTo: apiKeyField.bottomAnchor, constant: 12),
            saveButton.leadingAnchor.constraint(equalTo: providerTitle.leadingAnchor),
            saveButton.topAnchor.constraint(equalTo: detail.bottomAnchor, constant: 17),
            replaceButton.leadingAnchor.constraint(equalTo: providerTitle.leadingAnchor),
            replaceButton.topAnchor.constraint(equalTo: detail.bottomAnchor, constant: 17),
            statusLabel.leadingAnchor.constraint(equalTo: saveButton.trailingAnchor, constant: 12),
            statusLabel.centerYAnchor.constraint(equalTo: saveButton.centerYAnchor),
            shortcutTitle.leadingAnchor.constraint(equalTo: providerTitle.leadingAnchor),
            shortcutTitle.topAnchor.constraint(equalTo: saveButton.bottomAnchor, constant: 31),
            shortcutValueLabel.leadingAnchor.constraint(equalTo: shortcutTitle.leadingAnchor),
            shortcutValueLabel.topAnchor.constraint(equalTo: shortcutTitle.bottomAnchor, constant: 10),
            changeShortcutButton.leadingAnchor.constraint(equalTo: shortcutValueLabel.trailingAnchor, constant: 14),
            changeShortcutButton.centerYAnchor.constraint(equalTo: shortcutValueLabel.centerYAnchor),
            shortcutHelp.leadingAnchor.constraint(equalTo: providerTitle.leadingAnchor),
            shortcutHelp.trailingAnchor.constraint(equalTo: apiKeyField.trailingAnchor),
            shortcutHelp.topAnchor.constraint(equalTo: shortcutValueLabel.bottomAnchor, constant: 11)
        ])

        refreshKeyState()
    }

    required init?(coder: NSCoder) { nil }

    func present() {
        providerPopup.selectItem(withTitle: provider.displayName)
        refreshKeyState()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func providerDidChange() {
        guard let selected = providerPopup.titleOfSelectedItem,
              let provider = AIProvider.allCases.first(where: { $0.displayName == selected })
        else { return }
        ProviderStore.current = provider
        apiKeyField.stringValue = ""
        refreshKeyState()
    }

    @objc private func save() {
        let key = apiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            statusLabel.stringValue = "Paste a key to save it."
            statusLabel.textColor = .systemRed
            return
        }
        do {
            try KeychainStore.saveAPIKey(key, for: provider)
            onAPIKeySaved?(provider, key)
            apiKeyField.stringValue = ""
            hasSavedKey = true
            updateKeyState(message: "Saved in Keychain")
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

    private func refreshKeyState() {
        hasSavedKey = KeychainStore.hasAPIKey(for: provider)
        updateKeyState()
    }

    private func updateKeyState(message: String? = nil) {
        let providerName = provider.displayName
        apiKeyTitle.stringValue = "\(providerName) API key"
        detail.stringValue = "Promptly uses \(provider.defaultModel) with \(providerName). The key stays in your macOS Keychain. Each scan sends recognized text—not a screenshot—to the provider you select."
        apiKeyField.isHidden = hasSavedKey
        saveButton.isHidden = hasSavedKey
        replaceButton.isHidden = !hasSavedKey

        if hasSavedKey {
            statusLabel.stringValue = message ?? "\(providerName) key: Set"
            statusLabel.textColor = .systemGreen
        } else {
            apiKeyField.placeholderString = "Paste a \(providerName) API key"
            statusLabel.stringValue = "\(providerName) key: Not set"
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
