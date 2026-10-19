import AppKit
import CoreGraphics

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKey: GlobalHotKey?
    private var statusItem: NSStatusItem?
    private var scanMenuItem: NSMenuItem?
    private var lastResultItem: NSMenuItem?
    private var resetStatusWorkItem: DispatchWorkItem?
    private let settings = SettingsWindowController()
    private var cachedAPIKeys: [AIProvider: String] = [:]

    private static let requestedScreenCaptureKey = "didRequestScreenCaptureAccess"
    private static let screenRecordingSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    )!

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        hotKey = GlobalHotKey { [weak self] in
            self?.scanCurrentScreen()
        }
        settings.onAPIKeySaved = { [weak self] provider, key in
            self?.cachedAPIKeys[provider] = key
        }
        NotificationCenter.default.addObserver(self, selector: #selector(shortcutDidChange), name: ShortcutStore.shortcutDidChange, object: nil)
        setIdleStatus(detail: "Ready — press \(ShortcutStore.current().display) to scan visible text.")
    }

    private func scanCurrentScreen() {
        guard CGPreflightScreenCaptureAccess() else {
            // Ask macOS only once. Later scans report the problem without
            // re-prompting or pulling focus away from the frontmost app.
            guard !hasRequestedScreenCapture else {
                setTransientStatus(
                    title: "!",
                    detail: "Screen Recording is off for Promptly. Choose Check Screen Recording Permission to open System Settings."
                )
                return
            }
            let granted = requestScreenCaptureAccess()
            let detail = granted
                ? "Screen Recording is available. Press the shortcut again to scan."
                : "Screen Recording is not granted to Promptly. Allow it in System Settings, then relaunch Promptly."
            setTransientStatus(title: granted ? "✓" : "!", detail: detail)
            return
        }
        setTransientStatus(title: "…", detail: "Reading visible text…")
        Task { [weak self] in
            guard let self else { return }
            do {
                let text = try await ScreenReader.captureRecognizedText()
                guard !text.isEmpty else {
                    self.setTransientStatus(title: "!", detail: "No text found. Keep the question visible and try again.")
                    return
                }
                let provider = ProviderStore.current
                guard let apiKey = try self.apiKeyForCurrentSession(for: provider) else {
                    self.setTransientStatus(title: "!", detail: "Add your \(provider.displayName) API key from Settings, then scan again.")
                    return
                }
                self.setTransientStatus(title: "…", detail: "Analyzing recognized text with \(provider.displayName)…")
                let answer = try await AIClient.analyze(recognizedText: text, provider: provider, apiKey: apiKey)
                self.setTransientStatus(title: AnswerParser.displayAnswer(from: answer), detail: answer)
            } catch {
                self.setTransientStatus(title: "!", detail: "Could not complete the scan: \(error.localizedDescription)")
            }
        }
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let menu = NSMenu()
        let scanItem = NSMenuItem(title: "", action: #selector(scanFromMenu), keyEquivalent: "")
        menu.addItem(scanItem)
        scanMenuItem = scanItem
        updateShortcutMenuLabel()
        menu.addItem(withTitle: "Check Screen Recording Permission", action: #selector(checkScreenRecordingPermission), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        let lastResult = NSMenuItem(title: "Ready", action: nil, keyEquivalent: "")
        lastResult.isEnabled = false
        menu.addItem(lastResult)
        lastResultItem = lastResult
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Promptly", action: #selector(quit), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    @objc private func scanFromMenu() {
        scanCurrentScreen()
    }

    @objc private func openSettings() {
        settings.present()
    }

    @objc private func shortcutDidChange() {
        updateShortcutMenuLabel()
        setIdleStatus(detail: "Ready — press \(ShortcutStore.current().display) to scan visible text.")
    }

    @objc private func checkScreenRecordingPermission() {
        if CGPreflightScreenCaptureAccess() {
            setTransientStatus(title: "✓", detail: "Screen Recording permission is active for Promptly.")
        } else if hasRequestedScreenCapture {
            // macOS shows its own prompt only once; send the user to the setting instead.
            NSWorkspace.shared.open(Self.screenRecordingSettingsURL)
            setTransientStatus(title: "!", detail: "Turn on Promptly under Screen & System Audio Recording, then quit and reopen the app.")
        } else {
            let granted = requestScreenCaptureAccess()
            setTransientStatus(
                title: granted ? "✓" : "!",
                detail: granted
                    ? "Screen Recording is available."
                    : "Allow Screen Recording for Promptly in System Settings, then quit and reopen the app."
            )
        }
    }

    private var hasRequestedScreenCapture: Bool {
        UserDefaults.standard.bool(forKey: Self.requestedScreenCaptureKey)
    }

    private func requestScreenCaptureAccess() -> Bool {
        UserDefaults.standard.set(true, forKey: Self.requestedScreenCaptureKey)
        // Privacy prompts are more reliable when the requester is the active app.
        NSApp.activate(ignoringOtherApps: true)
        return CGRequestScreenCaptureAccess()
    }

    private func apiKeyForCurrentSession(for provider: AIProvider) throws -> String? {
        if let cachedKey = cachedAPIKeys[provider] { return cachedKey }
        let key = try KeychainStore.loadAPIKey(for: provider)
        cachedAPIKeys[provider] = key
        return key
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func setIdleStatus(detail: String) {
        resetStatusWorkItem?.cancel()
        statusItem?.button?.title = ""
        statusItem?.button?.image = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "Promptly")
        statusItem?.button?.toolTip = detail
        lastResultItem?.title = detail
    }

    private func setTransientStatus(title: String, detail: String) {
        resetStatusWorkItem?.cancel()
        statusItem?.button?.image = nil
        statusItem?.button?.title = title
        statusItem?.button?.toolTip = detail
        lastResultItem?.title = detail

        let work = DispatchWorkItem { [weak self] in
            self?.setIdleStatus(detail: "Ready — press \(ShortcutStore.current().display) to scan visible text.")
        }
        resetStatusWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }

    private func updateShortcutMenuLabel() {
        scanMenuItem?.title = "Scan visible screen   \(ShortcutStore.current().display)"
    }
}
