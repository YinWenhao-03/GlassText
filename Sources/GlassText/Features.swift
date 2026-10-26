import AppKit

extension App {
    @objc func cancelLoad() {
        job?.cancel(); job = nil; loadGeneration += 1
        cancelButton?.isHidden = true
        if fileLabel != nil { fileLabel.stringValue = committedLabel }
    }
    @objc func styleChanged() {
        content.weight = [.regular, .medium, .bold][weightPicker.indexOfSelectedItem]
        content.alignment = [.left, .center, .right][alignPicker.indexOfSelectedItem]
        content.lineSpacing = CGFloat(spacingSlider.doubleValue)
        content.textOpacity = CGFloat(opacitySlider.doubleValue); content.backdrop = CGFloat(backdropSlider.doubleValue)
        reflow(); saveState()
    }
    @objc func jumpPage() {
        guard canPage else { pageField.stringValue = String(page+1); return }
        guard let number = Int(pageField.stringValue), number >= 1, number <= (pdf?.pageCount ?? textPages.count) else {
            NSSound.beep(); pageField.stringValue = String(page+1); return
        }
        exitPrompt(); page = number-1; render()
    }
    @objc func changeSpeed(_ slider: NSSlider) { promptSpeed = slider.doubleValue; saveState() }
    @objc func changeKey() { registerRecoveryKey(); saveState() }
    func pausePrompt() {
        timer?.invalidate(); timer = nil; content.countdown = ""
        promptButton?.title = content.continuous ? "继续提词" : "开始提词（3 秒倒计时）"
    }
    func exitPrompt() { pausePrompt(); content.continuous = false; content.scrollOffset = 0 }
    @objc func restartPrompt() { guard canPage else { return }; exitPrompt(); if pdf == nil { togglePrompt() } }
    @objc func togglePrompt() {
        guard pdf == nil, canPage else { return }
        if timer != nil { pausePrompt(); return }
        if !content.continuous { content.continuous = true; content.scrollOffset = 0; content.text = sourceText }
        countdownRemaining = 3; content.countdown = "3"; lastTick = Date()
        promptButton.title = "暂停提词"
        let ticker = Timer(timeInterval: 1.0/30, repeats: true) { [weak self] _ in self?.tickPrompt() }
        timer = ticker; RunLoop.main.add(ticker, forMode: .common)
        promptHeight = measuredPromptHeight(); overlay.orderFrontRegardless()
    }
    func measuredPromptHeight() -> CGFloat { content.scrollTextHeight }
    func tickPrompt() {
        let now = Date(); let elapsed = now.timeIntervalSince(lastTick)
        if countdownRemaining > 0 {
            if elapsed >= 1 { countdownRemaining -= 1; lastTick = now; content.countdown = countdownRemaining > 0 ? String(countdownRemaining) : "" }
            return
        }
        lastTick = now
        let limit = max(0, promptHeight-content.readingArea.height)
        content.scrollOffset = min(limit, content.scrollOffset + CGFloat(min(0.1, elapsed)*promptSpeed))
        if content.scrollOffset >= limit { pausePrompt(); promptButton.title = "已到末尾 · 从头开始" }
    }
    func refreshScreens() {
        screenPicker.removeAllItems(); screenPicker.addItems(withTitles: NSScreen.screens.map { $0.localizedName })
        if let current = overlay.screen, let i = NSScreen.screens.firstIndex(of: current) { screenPicker.selectItem(at: i) }
    }
    static func clamped(_ rect: NSRect, to screen: NSRect) -> NSRect {
        let width = min(rect.width, screen.width), height = min(rect.height, screen.height)
        return NSRect(x: max(screen.minX, min(rect.minX, screen.maxX-width)), y: max(screen.minY, min(rect.minY, screen.maxY-height)), width: width, height: height)
    }
    @objc func screensChanged() {
        guard let main = NSScreen.main else { return }
        for window in [overlay!, panel!] + extras {
            let target = NSScreen.screens.max { $0.visibleFrame.intersection(window.frame).size.area < $1.visibleFrame.intersection(window.frame).size.area } ?? main
            window.setFrame(Self.clamped(window.frame, to: target.visibleFrame), display: true)
        }
        refreshScreens(); reflow()
    }
    @objc func moveScreen() {
        let i = screenPicker.indexOfSelectedItem
        guard NSScreen.screens.indices.contains(i) else { return }
        let frame = NSScreen.screens[i].visibleFrame
        var rect = overlay.frame; rect.origin = NSPoint(x: frame.midX-rect.width/2, y: frame.midY-rect.height/2)
        overlay.setFrame(Self.clamped(rect, to: frame), display: true); reflow()
    }
    func saveState() {
        guard (!testing || allowTestPersistence), stateReady, restoredPage == nil else { return }
        let rgb = content.ink.usingColorSpace(.deviceRGB) ?? .white
        defaults.set(["font": Double(content.fontSize), "spacing": Double(content.lineSpacing), "opacity": Double(content.textOpacity), "backdrop": Double(content.backdrop), "speed": promptSpeed, "white": whiteSlider.doubleValue, "r": rgb.redComponent, "g": rgb.greenComponent, "b": rgb.blueComponent], forKey: "style")
        defaults.set(weightPicker.indexOfSelectedItem, forKey: "weight"); defaults.set(alignPicker.indexOfSelectedItem, forKey: "alignment")
        defaults.set(content.outlined, forKey: "outline"); defaults.set(pinButton.state == .on, forKey: "pin")
        defaults.set(removeWhite.state == .on, forKey: "removeWhite"); defaults.set(keyPicker.indexOfSelectedItem, forKey: "hotkey")
        defaults.set(modePicker.indexOfSelectedItem, forKey: "wordMode")
        defaults.set(NSStringFromRect(overlay.frame), forKey: "frame")
        defaults.set(sourceURL?.path, forKey: "sourceURL"); defaults.set(sourceURL == nil ? sourceText : "", forKey: "sourceText")
        defaults.set(Double(content.zoom), forKey: "zoom"); defaults.set(lockPaging.state == .on, forKey: "lockPaging"); defaults.set(lockZoom.state == .on, forKey: "lockZoom")
        defaults.set(page, forKey: "page"); defaults.set(true, forKey: "configured")
    }
    func restoreState() {
        guard defaults.bool(forKey: "configured") else { fileLabel.stringValue = "欢迎使用：输入文字，或把文件拖到透明窗口"; return }
        content.zoom = min(3,max(0.5, defaults.object(forKey: "zoom") == nil ? 1 : defaults.double(forKey: "zoom")))
        lockPaging.state = defaults.bool(forKey: "lockPaging") ? .on : .off; lockZoom.state = defaults.bool(forKey: "lockZoom") ? .on : .off; refreshInteractionPolicy()
        let values = defaults.dictionary(forKey: "style") as? [String: Double] ?? [:]
        fontSlider.doubleValue = min(96, max(16, values["font"] ?? 36)); content.fontSize = CGFloat(fontSlider.doubleValue)
        spacingSlider.doubleValue = values["spacing"] ?? 10; opacitySlider.doubleValue = values["opacity"] ?? 1; backdropSlider.doubleValue = values["backdrop"] ?? 0
        speedSlider.doubleValue = values["speed"] ?? 30; promptSpeed = speedSlider.doubleValue; whiteSlider.doubleValue = values["white"] ?? 1
        content.ink = NSColor(deviceRed: values["r"] ?? 1, green: values["g"] ?? 1, blue: values["b"] ?? 1, alpha: 1); colorWell.color = content.ink
        weightPicker.selectItem(at: min(2,max(0, defaults.integer(forKey: "weight")))); alignPicker.selectItem(at: min(2,max(0,defaults.integer(forKey: "alignment"))))
        keyPicker.selectItem(at: min(2,max(0,defaults.integer(forKey: "hotkey")))); modePicker.selectItem(at: min(1,max(0, defaults.integer(forKey: "wordMode"))))
        content.outlined = defaults.bool(forKey: "outline"); outlineBox.state = content.outlined ? .on : .off
        removeWhite.state = defaults.bool(forKey: "removeWhite") ? .on : .off
        pinButton.state = defaults.bool(forKey: "pin") ? .on : .off; togglePin()
        if let rect = defaults.string(forKey: "frame") { let frame = NSRectFromString(rect); if frame.width >= 360 && frame.height >= 240 { overlay.setFrame(frame, display: true) } }
        styleChanged(); screensChanged()
        let savedPage = defaults.integer(forKey: "page")
        if let path = defaults.string(forKey: "sourceURL"), FileManager.default.fileExists(atPath: path) { restoredPage = savedPage; load(URL(fileURLWithPath: path)) }
        else {
            sourceText = defaults.string(forKey: "sourceText") ?? content.text; editor.string = sourceText; paginate(sourceText)
            page = min(savedPage,max(0,textPages.count-1)); render()
        }
    }
    @objc func newSnapshot() {
        guard extras.count < 8 else { NSSound.beep(); return }
        let view = ContentView(frame: content.bounds)
        view.text = content.continuous ? (textPages.indices.contains(page) ? textPages[page] : sourceText) : content.text
        view.zoom = content.zoom; view.pageImage = content.pageImage; view.fontSize = content.fontSize; view.ink = content.ink; view.outlined = content.outlined
        view.weight = content.weight; view.lineSpacing = content.lineSpacing; view.alignment = content.alignment; view.textOpacity = content.textOpacity; view.backdrop = content.backdrop
        let window = NSWindow(contentRect: overlay.frame.offsetBy(dx: 30, dy: -30), styleMask: [.borderless, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = false
        window.contentView = view; window.level = overlay.level; window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = locked; view.adjusting = !locked
        extras.append(window); window.orderFrontRegardless()
    }
    @objc func closeSnapshots() { extras.forEach { $0.close() }; extras.removeAll() }
    @objc func checkUpdates() {
        NSWorkspace.shared.open(URL(string: "https://github.com/YinWenhao-03/GlassText/releases")!)
    }
}
private extension NSSize { var area: CGFloat { max(0,width) * max(0,height) } }
