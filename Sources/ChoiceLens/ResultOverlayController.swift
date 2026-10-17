import AppKit

@MainActor
final class ResultOverlayController {
    private let panel: OverlayPanel
    private let textField = NSTextField(wrappingLabelWithString: "")
    private let iconView = NSImageView()
    private var dismissWorkItem: DispatchWorkItem?

    init() {
        panel = OverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 230),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hasShadow = true
        panel.ignoresMouseEvents = true

        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 14
        effect.layer?.masksToBounds = true
        panel.contentView = effect

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentTintColor = .white
        effect.addSubview(iconView)

        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.textColor = .white
        textField.font = .systemFont(ofSize: 13, weight: .medium)
        textField.maximumNumberOfLines = 11
        textField.lineBreakMode = .byTruncatingTail
        effect.addSubview(textField)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 18),
            iconView.topAnchor.constraint(equalTo: effect.topAnchor, constant: 17),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            textField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            textField.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -18),
            textField.topAnchor.constraint(equalTo: effect.topAnchor, constant: 17),
            textField.bottomAnchor.constraint(lessThanOrEqualTo: effect.bottomAnchor, constant: -17)
        ])
    }

    func show(message: String, symbol: String) {
        dismissWorkItem?.cancel()
        textField.stringValue = message
        iconView.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        placePanelBelowMenuBar()
        panel.orderFrontRegardless()

        let work = DispatchWorkItem { [weak self] in self?.panel.orderOut(nil) }
        dismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 12, execute: work)
    }

    private func placePanelBelowMenuBar() {
        guard let screen = NSScreen.main else { return }
        let frame = panel.frame
        let x = screen.visibleFrame.maxX - frame.width - 12
        let y = screen.visibleFrame.maxY - frame.height - 12
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

private final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
