import AppKit
import PDFKit
import UniformTypeIdentifiers
import Carbon

final class FlippedView: NSView { override var isFlipped: Bool { true } }

final class ContentView: NSView {
    private var scrollingLayout: (NSTextStorage, NSLayoutManager, NSTextContainer, CGFloat)?
    func scrollLayout() -> (NSLayoutManager, NSTextContainer) {
        if scrollingLayout == nil || scrollingLayout!.3 != readingArea.width {
            let storage = NSTextStorage(string: text, attributes: attributes)
            let layout = NSLayoutManager(); storage.addLayoutManager(layout)
            let container = NSTextContainer(containerSize: NSSize(width: readingArea.width, height: CGFloat.greatestFiniteMagnitude)); container.lineFragmentPadding = 0
            layout.addTextContainer(container); layout.ensureLayout(for: container)
            scrollingLayout = (storage, layout, container, readingArea.width)
        }
        return (scrollingLayout!.1, scrollingLayout!.2)
    }
    var scrollTextHeight: CGFloat { let (layout, container) = scrollLayout(); return layout.usedRect(for: container).height }

    var text = "透明文字\n\n在控制面板输入文字，或打开 PDF / Word 文件。\n拖动文字区域可以移动窗口。" { didSet { scrollingLayout = nil; needsDisplay = true } }
    var lineSpacing: CGFloat = 10 { didSet { scrollingLayout = nil; needsDisplay = true } }
    var weight: NSFont.Weight = .medium { didSet { scrollingLayout = nil; needsDisplay = true } }
    var alignment: NSTextAlignment = .left { didSet { scrollingLayout = nil; needsDisplay = true } }
    var backdrop: CGFloat = 0 { didSet { needsDisplay = true } }
    var textOpacity: CGFloat = 1 { didSet { needsDisplay = true } }
    var scrollOffset: CGFloat = 0 { didSet { needsDisplay = true } }
    var continuous = false { didSet { needsDisplay = true } }
    var countdown = "" { didSet { needsDisplay = true } }
    var onFile: ((URL) -> Void)?
    var onResize: (() -> Void)?
    override init(frame: NSRect) { super.init(frame: frame); registerForDraggedTypes([.fileURL]) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { onFile != nil ? .copy : [] }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = (sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL])?.first, let handler = onFile else { return false }
        handler(url); return true
    }
    var attributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = lineSpacing; paragraph.alignment = alignment
        var values: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: fontSize * zoom, weight: weight), .foregroundColor: ink, .paragraphStyle: paragraph]
        if outlined {
            let rgb = ink.usingColorSpace(.deviceRGB) ?? .white
            values[.strokeColor] = 0.299*rgb.redComponent + 0.587*rgb.greenComponent + 0.114*rgb.blueComponent > 0.5 ? NSColor.black : NSColor.white
            values[.strokeWidth] = -3
        }
        return values
    }
    var pan = NSPoint.zero { didSet { needsDisplay = true } }
    var onPan: ((CGFloat, CGFloat) -> Void)?
    override func scrollWheel(with event: NSEvent) { if pageImage != nil { onPan?(event.scrollingDeltaX, event.scrollingDeltaY) } }
    var zoom: CGFloat = 1 { didSet { scrollingLayout = nil; needsDisplay = true } }
    var fontSize: CGFloat = 36 { didSet { scrollingLayout = nil; needsDisplay = true } }
    var ink = NSColor.white { didSet { scrollingLayout = nil; needsDisplay = true } }
    var outlined = true { didSet { scrollingLayout = nil; needsDisplay = true } }
    var adjusting = true { didSet { needsDisplay = true } }
    var readingArea: NSRect { NSRect(x: 24, y: 64, width: max(100, bounds.width-48), height: max(100, bounds.height-88)) }
    var pageImage: NSImage? { didSet { needsDisplay = true } }
    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    override func mouseDown(with event: NSEvent) {
        guard adjusting, let window = window else { return }
        let point = convert(event.locationInWindow, from: nil)
        if point.x > bounds.width-28 && point.y > bounds.height-28 {
            let initial = window.frame, start = NSEvent.mouseLocation
            while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
                if next.type == .leftMouseUp { break }
                let now = NSEvent.mouseLocation
                let width = max(360, initial.width + now.x-start.x)
                let height = max(240, initial.height - now.y+start.y)
                window.setFrame(NSRect(x: initial.minX, y: initial.maxY-height, width: width, height: height), display: true)
            }
            onResize?()
        } else { window.performDrag(with: event) }
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill(); dirtyRect.fill(using: .copy)
        if adjusting {
            NSColor.controlAccentColor.withAlphaComponent(0.7).setStroke()
            let frame = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 12, yRadius: 12)
            frame.lineWidth = 2; frame.stroke()
            ("◢" as NSString).draw(at: NSPoint(x: bounds.width-24, y: bounds.height-28), withAttributes: [.foregroundColor: NSColor.controlAccentColor, .font: NSFont.systemFont(ofSize: 22)])
        }
        let area = readingArea
        if backdrop > 0 { NSColor.black.withAlphaComponent(backdrop).setFill(); NSBezierPath(roundedRect: area.insetBy(dx: -8, dy: -8), xRadius: 10, yRadius: 10).fill() }
        NSGraphicsContext.saveGraphicsState(); area.clip()
        NSGraphicsContext.current?.cgContext.setAlpha(textOpacity)
        defer { NSGraphicsContext.restoreGraphicsState() }
        if let image = pageImage {
            let ratio = min(area.width / image.size.width, area.height / image.size.height) * zoom
            let size = NSSize(width: image.size.width * ratio, height: image.size.height * ratio)
            image.draw(in: NSRect(x: area.midX-size.width/2+pan.x, y: area.midY-size.height/2+pan.y, width: size.width, height: size.height), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        } else {
            if continuous {
                let (layout, container) = scrollLayout()
                let range = layout.glyphRange(forBoundingRect: NSRect(x: 0, y: scrollOffset, width: area.width, height: area.height), in: container)
                layout.drawGlyphs(forGlyphRange: range, at: NSPoint(x: area.minX, y: area.minY-scrollOffset))
            } else { (text as NSString).draw(with: area, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes) }
        }
        if !countdown.isEmpty {
            NSColor.black.withAlphaComponent(0.75).setFill(); NSBezierPath(roundedRect: area, xRadius: 12, yRadius: 12).fill()
            (countdown as NSString).draw(in: area, withAttributes: [.font: NSFont.systemFont(ofSize: 72, weight: .bold), .foregroundColor: NSColor.white])
        }
    }
}

final class App: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let content = ContentView(frame: NSRect(x: 0, y: 0, width: 900, height: 600))
    var overlay: NSWindow!
    var panel: NSWindow!
    var editor: NSTextView!
    var status: NSTextField!
    var pdf: PDFDocument?
    var page = 0
    var textPages: [String] = []
    var brandIcon: NSImage?
    var statusItem: NSStatusItem!
    var pinButton: NSButton!
    var passButton: NSButton!
    var toolbar: NSStackView!
    var styleRow: NSStackView!
    var textLayoutRow: NSStackView!
    var pdfRow: NSStackView!
    var removeWhite: NSButton!
    var fileLabel: NSTextField!
    var hotkeyLabel: NSTextField!
    var hotkey: EventHotKeyRef?
    var hotkeyHandler: EventHandlerRef?
    var sourceText = ""
    var pageStarts: [Int] = []
    var loadGeneration = 0
    var locked = false
    var lockPaging: NSButton!
    var lockZoom: NSButton!
    var zoomLabel: NSTextField!
    var lockSummary: NSTextField!
    var panRow: NSStackView!
    var pagingControls: [NSControl] = []
    var zoomControls: [NSControl] = []
    var sectionPicker: NSSegmentedControl!
    var sections: [NSView] = []
    var appearanceDetails: NSStackView!
    var preferences: NSWindow!
    var cancelButton: NSButton!
    var guide: NSWindow?
    var guideStep = 0
    var guideOriginalLock = false
    var guideTitle: NSTextField!
    var guideBody: NSTextField!
    var guideProgress: NSTextField!
    var guideNext: NSButton!
    var guidePicture: TutorialImage!
    var guideOriginalSection = 0
    var stateReady = false
    let testSuite = "GlassText.Tests." + UUID().uuidString
    var allowTestPersistence = false
    var defaults: UserDefaults { testing ? UserDefaults(suiteName: testSuite)! : UserDefaults.standard }
    var testing: Bool { CommandLine.arguments.contains("--self-test") }
    var sourceURL: URL?
    var pageField: NSTextField!
    var promptButton: NSButton!
    var speedSlider: NSSlider!
    var modePicker: NSPopUpButton!
    var whiteSlider: NSSlider!
    var fontSlider: NSSlider!
    var colorWell: NSColorWell!
    var outlineBox: NSButton!
    var weightPicker: NSPopUpButton!
    var alignPicker: NSPopUpButton!
    var spacingSlider: NSSlider!
    var opacitySlider: NSSlider!
    var backdropSlider: NSSlider!
    var keyPicker: NSPopUpButton!
    var screenPicker: NSPopUpButton!
    var timer: Timer?
    var promptSpeed: Double = 30
    var promptHeight: CGFloat = 0
    var countdownRemaining = 0
    var lastTick = Date()
    var job: ImportJob?
    var pdfCache = NSCache<NSString, NSImage>()
    var restoredPage: Int?
    var extras: [NSWindow] = []
    var committedLabel = "输入文字，或打开文件开始预览"

    func registerRecoveryKey() {
        if let old = hotkey { UnregisterEventHotKey(old); hotkey = nil }
        if let old = hotkeyHandler { RemoveEventHandler(old); hotkeyHandler = nil }
        let callback: EventHandlerUPP = { _, _, pointer in
            guard let pointer = pointer else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<App>.fromOpaque(pointer).takeUnretainedValue()
            owner.recover(); return noErr
        }
        InstallEventHandler(GetApplicationEventTarget(), callback, 1,
            [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))],
            Unmanaged.passUnretained(self).toOpaque(), &hotkeyHandler)
        let code: UInt32 = keyPicker.indexOfSelectedItem == 1 ? UInt32(kVK_ANSI_T) : keyPicker.indexOfSelectedItem == 2 ? UInt32(kVK_ANSI_R) : UInt32(kVK_ANSI_G)
        let result = RegisterEventHotKey(code, UInt32(cmdKey | optionKey | controlKey),
            EventHotKeyID(signature: 0x47545854, id: 1), GetApplicationEventTarget(), 0, &hotkey)
        hotkeyLabel.stringValue = result == noErr ? "全局恢复：⌃⌥⌘" + (keyPicker.titleOfSelectedItem ?? "G") + " · 解锁并显示控制面板" : "恢复快捷键被占用，请使用菜单栏“透 Aa”恢复"
    }
    func applicationWillTerminate(_ notification: Notification) {
        saveState(); job?.cancel(); timer?.invalidate()
        if let key = hotkey { UnregisterEventHotKey(key) }
        if let handler = hotkeyHandler { RemoveEventHandler(handler) }
    }
    @objc func recover() { pausePrompt(); setLocked(false); overlay.orderFrontRegardless(); showPanel() }
    func setLocked(_ value: Bool) {
        for window in extras { window.ignoresMouseEvents = value; (window.contentView as? ContentView)?.adjusting = !value }
        locked = value; refreshInteractionPolicy(); overlay.ignoresMouseEvents = value; content.adjusting = !value
        toolbar.isHidden = value; passButton.state = value ? .on : .off; passButton.title = value ? "返回调整" : "锁定展示"
        statusItem.button?.title = value ? "透 · 已锁定" : "透 · 调整中"
    }
    func reflow() { if pdf == nil && !content.continuous { paginate(sourceText) }; if content.continuous { promptHeight = measuredPromptHeight() }; saveState() }
    func placeWindows() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let panelWidth: CGFloat = 480
        panel.setFrameOrigin(NSPoint(x: frame.minX+20, y: max(frame.minY, frame.midY-panel.frame.height/2)))
        let width = max(360, min(900, frame.width-panelWidth-60))
        let height = min(600, frame.height-40)
        overlay.setFrame(NSRect(x: frame.maxX-width-20, y: frame.midY-height/2, width: width, height: height), display: true)
        reflow()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        brandIcon = AppArtwork.load()
        if let icon = brandIcon { NSApp.applicationIconImage = icon; NSApp.dockTile.display() }
        buildMenu()
        overlay = NSWindow(contentRect: NSRect(x: 240, y: 180, width: 900, height: 600), styleMask: [.borderless, .resizable], backing: .buffered, defer: false)
        overlay.isOpaque = false; overlay.backgroundColor = .clear; overlay.hasShadow = false
        overlay.isMovableByWindowBackground = true; overlay.level = .floating
        overlay.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        overlay.contentView = content; overlay.makeKeyAndOrderFront(nil)
        overlay.delegate = self
        toolbar = row([button("←", #selector(previous)), button("→", #selector(next)), button("外观", #selector(showPanel)), button("锁定展示", #selector(togglePass)), button("隐藏", #selector(toggleVisible))])
        toolbar.wantsLayer = true; toolbar.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor; toolbar.layer?.cornerRadius = 8
        toolbar.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(toolbar)
        NSLayoutConstraint.activate([toolbar.topAnchor.constraint(equalTo: content.topAnchor, constant: 12), toolbar.centerXAnchor.constraint(equalTo: content.centerXAnchor)])
        buildPanel(); sourceText = editor.string; placeWindows()
        content.onFile = { [weak self] in self?.load($0) }; content.onResize = { [weak self] in self?.reflow() }
        content.onPan = { [weak self] x,y in self?.panBy(x,y) }
        pdfCache.totalCostLimit = 64 * 1024 * 1024; pdfCache.countLimit = 8
        if !testing { restoreState() }; stateReady = true
        refreshScreens(); registerRecoveryKey()
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSApp.activate(ignoringOtherApps: true)
        if CommandLine.arguments.contains("--self-test") { selfTest(); NSApp.terminate(nil) }
        else if !defaults.bool(forKey: "onboardingComplete") { showGuide() }
    }
    func windowDidMove(_ notification: Notification) { saveState() }
    func windowDidEndLiveResize(_ notification: Notification) { reflow() }
    func selfTest() {
        editor.string = String(repeating: "透明文字 pagination test 中文测试。\n", count: 100)
        applyText()
        precondition(textPages.count > 1)
        precondition(textPages.joined() == editor.string)
        next(); precondition(page == 1); previous(); precondition(page == 0)
        page = min(3, textPages.count-1)
        let anchor = pageStarts[page]
        content.fontSize = 48; reflow()
        precondition(pageStarts[page] <= anchor)
        precondition(page == pageStarts.count-1 || pageStarts[page+1] > anchor)
        precondition(textPages.joined() == sourceText)
        editor.string = "未放映的草稿"
        reflow(); precondition(textPages.joined() == sourceText)
        setLocked(true); precondition(toolbar.isHidden && !content.adjusting)
        recover(); precondition(!locked && !toolbar.isHidden && content.adjusting)
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let fixture = "中文 Word 测试\n第二段内容。"
        let txt = temporary.appendingPathComponent("fixture.txt")
        let docx = temporary.appendingPathComponent("fixture.docx")
        try! fixture.write(to: txt, atomically: true, encoding: .utf8)
        let conversion = Process(); conversion.executableURL = URL(fileURLWithPath: "/usr/bin/textutil")
        conversion.arguments = ["-convert", "docx", "-output", docx.path, txt.path]
        try! conversion.run(); conversion.waitUntilExit(); precondition(conversion.terminationStatus == 0)
        if case .text(let value) = try! App.read(docx) { precondition(value.contains(fixture)) } else { preconditionFailure() }
        let oldSource = sourceText
        do { _ = try App.read(temporary.appendingPathComponent("missing.docx")); preconditionFailure() } catch { precondition(sourceText == oldSource) }
        let empty = temporary.appendingPathComponent("empty.txt")
        try! "".write(to: empty, atomically: true, encoding: .utf8)
        do { _ = try App.read(empty); preconditionFailure() } catch {}
        let broken = temporary.appendingPathComponent("broken.pdf")
        try! "not a pdf".write(to: broken, atomically: true, encoding: .utf8)
        do { _ = try App.read(broken); preconditionFailure() } catch {}
        togglePass(); precondition(overlay.ignoresMouseEvents); togglePass()
        pinButton.state = .off; togglePin(); precondition(overlay.level == .normal)
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 200, height: 200)
        let consumer = CGDataConsumer(data: data)!
        let context = CGContext(consumer: consumer, mediaBox: &box, nil)!
        context.beginPDFPage(nil); context.setFillColor(NSColor.white.cgColor); context.fill(box)
        context.setFillColor(NSColor.black.cgColor); context.fill(CGRect(x: 50, y: 50, width: 50, height: 50))
        context.endPDFPage(); context.closePDF()
        pdf = PDFDocument(data: data as Data); page = 0; render()
        let bitmap = NSBitmapImageRep(data: content.pageImage!.tiffRepresentation!)!
        precondition(bitmap.colorAt(x: 0, y: 0)!.alphaComponent < 0.01)
        precondition(bitmap.colorAt(x: bitmap.pixelsWide * 3 / 8, y: bitmap.pixelsHigh * 5 / 8)!.alphaComponent > 0.99)
        precondition(styleRow.isHidden && !pdfRow.isHidden)
        removeWhite.state = .off; render()
        let original = NSBitmapImageRep(data: content.pageImage!.tiffRepresentation!)!
        precondition(original.colorAt(x: 0, y: 0)!.alphaComponent > 0.99)
        print("PASS: Chinese pagination, reading anchor, draft isolation, lock/recovery, Word import, invalid/empty files, PDF transparency and original-page toggle")
        featureChecks(directory: temporary, docx: docx)
    }
    func item(_ title: String, _ action: Selector, _ key: String = "") -> NSMenuItem {
        let result = NSMenuItem(title: title, action: action, keyEquivalent: key); result.target = self; return result
    }
    func buildMenu() {
        let main = NSMenu(); let appItem = NSMenuItem(); main.addItem(appItem)
        let menu = NSMenu(); appItem.submenu = menu
        menu.addItem(item("显示控制面板", #selector(showPanel), "0"))
        menu.addItem(item("打开文件…", #selector(openFile), "o"))
        menu.addItem(item("锁定 / 调整", #selector(togglePass), "i"))
        menu.addItem(item("恢复操作", #selector(recover)))
        menu.addItem(item("放大", #selector(zoomIn), "+"))
        menu.addItem(item("缩小", #selector(zoomOut), "-"))
        menu.addItem(item("重置缩放", #selector(resetZoom), "1"))
        menu.addItem(item("显示 / 隐藏", #selector(toggleVisible)))
        menu.addItem(item("上一页", #selector(previous), "[")); menu.addItem(item("下一页", #selector(next), "]"))
        menu.addItem(item("新建当前页悬浮副本", #selector(newSnapshot)))
        menu.addItem(item("关闭全部副本", #selector(closeSnapshots)))
        menu.addItem(item("暂停 / 继续提词", #selector(togglePrompt)))
        menu.addItem(item("查看更新", #selector(checkUpdates)))
        menu.addItem(item("新手引导", #selector(showGuide)))
        menu.addItem(.separator()); menu.addItem(item("退出透明文字", #selector(quit), "q"))
        let editItem = NSMenuItem(); editItem.title = "编辑"; main.addItem(editItem)
        let edit = NSMenu(title: "编辑"); editItem.submenu = edit
        for (title, action, key) in [("剪切", "cut:", "x"), ("复制", "copy:", "c"), ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a")] { edit.addItem(NSMenuItem(title: title, action: Selector(action), keyEquivalent: key)) }
        NSApp.mainMenu = main
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "透 Aa"; statusItem.menu = menu.copy() as? NSMenu
    }
    func button(_ title: String, _ action: Selector) -> NSButton { NSButton(title: title, target: self, action: action) }
    func row(_ views: [NSView]) -> NSStackView { let stack = NSStackView(views: views); stack.spacing = 10; return stack }
    @objc func toggleOutline(_ sender: NSButton) { content.outlined = sender.state == .on; saveState() }
    @objc func refreshPDF() { render(); saveState() }
    @objc func showPanel() { panel.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func togglePin() { overlay.level = pinButton.state == .on ? .floating : .normal; saveState() }
    @objc func togglePass() { setLocked(!locked) }
    @objc func toggleVisible() { if overlay.isVisible { pausePrompt(); overlay.orderOut(nil); extras.forEach { $0.orderOut(nil) } } else { overlay.orderFrontRegardless(); extras.forEach { $0.orderFrontRegardless() } } }
    @objc func resetPosition() { placeWindows(); recover() }
    @objc func changeSize(_ sender: NSSlider) { guard canZoom else { sender.doubleValue = Double(content.fontSize); return }; content.fontSize = CGFloat(sender.doubleValue); reflow() }
    @objc func changeColor(_ sender: NSColorWell) { content.ink = sender.color; saveState() }
    @objc func applyText() {
        guard editor.string.utf16.count <= 2_000_000 else { let alert = NSAlert(error: ImportFailure.large); alert.beginSheetModal(for: panel); return }
        cancelLoad(); exitPrompt(); sourceURL = nil; pdfCache.removeAllObjects(); loadGeneration += 1; pdf = nil; page = 0; pageStarts = []; sourceText = editor.string
        committedLabel = "输入文字 · 纯文字展示"; fileLabel.stringValue = committedLabel; paginate(sourceText); overlay.orderFrontRegardless(); saveState()
    }
    func paginate(_ text: String) {
        let anchor = pageStarts.indices.contains(page) ? pageStarts[page] : 0
        let width = content.readingArea.width, height = content.readingArea.height
        let storage = NSTextStorage(string: text, attributes: content.attributes)
        let layout = NSLayoutManager(); storage.addLayoutManager(layout)
        textPages = []; pageStarts = []; var consumed = 0
        while consumed < storage.length {
            let container = NSTextContainer(containerSize: NSSize(width: width, height: height)); container.lineFragmentPadding = 0
            layout.addTextContainer(container)
            let glyphs = layout.glyphRange(for: container)
            let range = layout.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
            if range.length == 0 { break }
            pageStarts.append(range.location); textPages.append((text as NSString).substring(with: range)); consumed = NSMaxRange(range)
        }
        if textPages.isEmpty { textPages = [""]; pageStarts = [0] }; page = pageStarts.lastIndex(where: { $0 <= anchor }) ?? 0; render()
    }
    @objc func previous() { guard canPage else { return }; exitPrompt(); page = max(0, page-1); render() }
    @objc func next() { guard canPage else { return }; exitPrompt(); page = min((pdf?.pageCount ?? textPages.count)-1, page+1); page = max(0, page); render() }
    func render() {
        panRow.isHidden = pdf == nil || content.zoom <= 1
        styleRow.isHidden = pdf != nil; textLayoutRow.isHidden = pdf != nil; pdfRow.isHidden = pdf == nil
        promptButton.isEnabled = pdf == nil && canPage
        pageField.stringValue = String(page+1)
        defer { refreshInteractionPolicy(); saveState() }
        if let pdf = pdf, let source = pdf.page(at: page) {
            let cacheKey = "\(ObjectIdentifier(pdf))-\(page)-\(removeWhite.state.rawValue)-\(Int(whiteSlider.doubleValue*100))" as NSString
            if let cached = pdfCache.object(forKey: cacheKey) { content.pageImage = cached; status.stringValue = "PDF  \(page+1) / \(pdf.pageCount)"; return }
            let thumbnail = source.thumbnail(of: NSSize(width: 1800, height: 1800), for: .mediaBox)
            guard let tiff = thumbnail.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let cg = bitmap.cgImage else { return }
            let w = cg.width, h = cg.height
            var pixels = [UInt8](repeating: 0, count: w*h*4)
            pixels.withUnsafeMutableBytes { bytes in
                guard let ctx = CGContext(data: bytes.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w*4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
                ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
                let p = bytes.bindMemory(to: UInt8.self)
                for i in stride(from: 0, to: p.count, by: 4) {
                    let white = removeWhite.state == .on ? UInt8(Double(min(p[i], min(p[i+1], p[i+2]))) * whiteSlider.doubleValue) : 0
                    p[i] -= white; p[i+1] -= white; p[i+2] -= white; p[i+3] = 255-white
                }
                if let result = ctx.makeImage() { let image = NSImage(cgImage: result, size: thumbnail.size); content.pageImage = image; pdfCache.setObject(image, forKey: cacheKey, cost: w*h*4) }
            }
            status.stringValue = "PDF  \(page+1) / \(pdf.pageCount)"
        } else {
            content.pageImage = nil; content.text = textPages.indices.contains(page) ? textPages[page] : editor.string
            status.stringValue = "文字  \(page+1) / \(max(1, textPages.count))"
        }
    }
    @objc func openFile() {
        let picker = NSOpenPanel(); picker.allowedContentTypes = ["pdf", "docx", "doc", "rtf", "txt", "md"].compactMap { UTType(filenameExtension: $0) }; picker.allowsMultipleSelection = false
        guard picker.runModal() == .OK, let url = picker.url else { return }
        load(url)
    }
    enum Loaded { case pdf(PDFDocument), text(String) }
    static func read(_ url: URL, job: ImportJob = ImportJob(), preserveLayout: Bool = false) throws -> Loaded {
        try DocumentImporter.read(url, job: job, preserveLayout: preserveLayout)
    }
    func load(_ url: URL) {
        cancelLoad(); let task = ImportJob(); job = task
        let layout = modePicker.indexOfSelectedItem == 1
        loadGeneration += 1; let generation = loadGeneration
        cancelButton.isHidden = false; fileLabel.stringValue = "正在读取：" + url.lastPathComponent
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try App.read(url, job: task, preserveLayout: layout) }
            DispatchQueue.main.async {
                guard generation == self.loadGeneration else { return }
                self.job = nil; self.cancelButton.isHidden = true
                switch result {
                case .success(let loaded):
                    self.exitPrompt(); self.sourceURL = url; self.pdfCache.removeAllObjects(); self.page = 0; self.pageStarts = []
                    switch loaded {
                    case .pdf(let document): self.pdf = document; self.render()
                    case .text(let text):
                        self.pdf = nil; self.editor.string = text; self.sourceText = text; self.paginate(text)
                    }
                    self.fileLabel.stringValue = url.lastPathComponent + (self.pdf == nil ? " · 纯文字展示" : " · 保留版式")
                    if let restored = self.restoredPage { self.page = min(restored, max(0, (self.pdf?.pageCount ?? self.textPages.count)-1)); self.restoredPage = nil; self.render() }
                    self.committedLabel = self.fileLabel.stringValue; self.saveState()
                    self.overlay.orderFrontRegardless()
                case .failure(let error):
                    self.restoredPage = nil
                    self.fileLabel.stringValue = self.committedLabel
                    let alert = NSAlert(error: error); alert.informativeText += "\n原有展示内容已保留。"; alert.beginSheetModal(for: self.panel)
                }
            }
        }
    }
}
let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.run()
