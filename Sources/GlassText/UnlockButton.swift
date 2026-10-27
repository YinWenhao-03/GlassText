import AppKit

extension App {
    func updateUnlockButton() {
        guard locked, overlay.isVisible else { unlockPanel?.orderOut(nil); return }
        if unlockPanel == nil {
            let window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 90, height: 34),
                                 styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = true
            window.hidesOnDeactivate = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let button = NSButton(title: "解锁", target: self, action: #selector(recover))
            button.bezelStyle = .rounded
            button.image = NSImage(systemSymbolName: "lock.open", accessibilityDescription: "解锁展示")
            button.imagePosition = .imageLeading
            button.toolTip = "返回调整，恢复展示窗口的鼠标操作"
            button.frame = NSRect(x: 0, y: 0, width: 90, height: 34)
            button.autoresizingMask = [.width, .height]
            window.contentView = button
            unlockPanel = window
        }
        guard let window = unlockPanel else { return }
        let target = NSRect(x: overlay.frame.maxX - 102, y: overlay.frame.maxY - 44, width: 90, height: 34)
        let screen = overlay.screen ?? NSScreen.main
        window.setFrame(screen.map { Self.clamped(target, to: $0.visibleFrame) } ?? target, display: true)
        window.level = NSWindow.Level(rawValue: max(overlay.level.rawValue, NSWindow.Level.floating.rawValue) + 1)
        window.orderFrontRegardless()
    }
}
