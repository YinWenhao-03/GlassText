import AppKit

extension App {
    func updateUnlockButton() {
        guard locked, overlay.isVisible else { unlockPanel?.orderOut(nil); return }
        if unlockPanel == nil {
            let window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 280, height: 40),
                                 styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = true
            window.hidesOnDeactivate = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let button = NSButton(title: "解锁 · 返回调整", target: self, action: #selector(recover))
            button.bezelStyle = .rounded
            button.controlSize = .large
            button.font = .systemFont(ofSize: 14, weight: .semibold)
            button.bezelColor = .controlAccentColor
            button.contentTintColor = .white
            button.setAccessibilityLabel("解锁展示并返回调整")
            button.image = NSImage(systemSymbolName: "lock.open", accessibilityDescription: "解锁展示")
            button.imagePosition = .imageLeading
            button.toolTip = "返回调整，恢复展示窗口的鼠标操作"
            unlockButton = button
            let prompt = NSButton(title: "开始提词", target: self, action: #selector(togglePrompt))
            prompt.bezelStyle = .rounded; prompt.controlSize = .large
            prompt.font = .systemFont(ofSize: 14, weight: .medium)
            lockedPromptButton = prompt
            let controls = row([button, prompt]); controls.spacing = 6
            controls.translatesAutoresizingMaskIntoConstraints = false
            let surface = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 40))
            surface.addSubview(controls)
            NSLayoutConstraint.activate([
                controls.centerYAnchor.constraint(equalTo: surface.centerYAnchor),
                controls.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 6),
                controls.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -6),
                button.widthAnchor.constraint(equalToConstant: 154),
                prompt.widthAnchor.constraint(equalToConstant: 108)
            ])
            window.contentView = surface
            unlockPanel = window
            refreshPromptControls()
        }
        guard let window = unlockPanel else { return }
        if window.parent !== overlay { overlay.addChildWindow(window, ordered: .above) }
        let target = NSRect(x: overlay.frame.maxX - 292, y: overlay.frame.maxY - 52, width: 280, height: 40)
        let screen = overlay.screen ?? NSScreen.main
        window.setFrame(screen.map { Self.clamped(target, to: $0.visibleFrame) } ?? target, display: true)
        window.level = NSWindow.Level(rawValue: max(overlay.level.rawValue, NSWindow.Level.floating.rawValue) + 1)
        window.orderFrontRegardless()
    }
}
