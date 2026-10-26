import AppKit
import PDFKit
import UniformTypeIdentifiers
import Carbon

final class ContentView: NSView {
    var text = "透明文字\n\n在控制面板输入文字，或打开 PDF / Word 文件。\n拖动文字区域可以移动窗口。" { didSet { needsDisplay = true } }
    var fontSize: CGFloat = 36 { didSet { needsDisplay = true } }
    var ink = NSColor.white { didSet { needsDisplay = true } }
    var outlined = true { didSet { needsDisplay = true } }
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
            (NSApp.delegate as? App)?.reflow()
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
        if let image = pageImage {
            let ratio = min(area.width / image.size.width, area.height / image.size.height)
            let size = NSSize(width: image.size.width * ratio, height: image.size.height * ratio)
            image.draw(in: NSRect(x: area.midX-size.width/2, y: area.midY-size.height/2, width: size.width, height: size.height), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        } else {
            let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = 10
            var attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: fontSize, weight: .medium), .foregroundColor: ink, .paragraphStyle: paragraph]
            if outlined {
                let rgb = ink.usingColorSpace(.deviceRGB) ?? .white
                let brightness = 0.299*rgb.redComponent + 0.587*rgb.greenComponent + 0.114*rgb.blueComponent
                attributes[.strokeColor] = brightness > 0.5 ? NSColor.black : NSColor.white
                attributes[.strokeWidth] = -3
            }
            (text as NSString).draw(in: area, withAttributes: attributes)
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
    var statusItem: NSStatusItem!
    var pinButton: NSButton!
    var passButton: NSButton!
    var toolbar: NSStackView!
    var styleRow: NSStackView!
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
    var committedLabel = "输入文字，或打开文件开始预览"

    func registerRecoveryKey() {
        let callback: EventHandlerUPP = { _, _, pointer in
            guard let pointer = pointer else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<App>.fromOpaque(pointer).takeUnretainedValue()
            owner.recover(); return noErr
        }
        InstallEventHandler(GetApplicationEventTarget(), callback, 1,
            [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))],
            Unmanaged.passUnretained(self).toOpaque(), &hotkeyHandler)
        let result = RegisterEventHotKey(UInt32(kVK_ANSI_G), UInt32(cmdKey | optionKey | controlKey),
            EventHotKeyID(signature: 0x47545854, id: 1), GetApplicationEventTarget(), 0, &hotkey)
        hotkeyLabel.stringValue = result == noErr ? "全局恢复：⌃⌥⌘G · 解锁并显示控制面板" : "恢复快捷键被占用，请使用菜单栏“透 Aa”恢复"
    }
    func applicationWillTerminate(_ notification: Notification) {
        if let key = hotkey { UnregisterEventHotKey(key) }
        if let handler = hotkeyHandler { RemoveEventHandler(handler) }
    }
    @objc func recover() { setLocked(false); overlay.orderFrontRegardless(); showPanel() }
    func setLocked(_ value: Bool) {
        locked = value; overlay.ignoresMouseEvents = value; content.adjusting = !value
        toolbar.isHidden = value; passButton.state = value ? .on : .off
        statusItem.button?.title = value ? "透 · 已锁定" : "透 · 调整中"
    }
    func reflow() { if pdf == nil { paginate(sourceText) } }
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
        buildPanel(); sourceText = editor.string; placeWindows(); registerRecoveryKey(); NSApp.activate(ignoringOtherApps: true)
        if CommandLine.arguments.contains("--self-test") { selfTest(); NSApp.terminate(nil) }
    }
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
        menu.addItem(item("显示 / 隐藏", #selector(toggleVisible)))
        menu.addItem(item("上一页", #selector(previous), "[")); menu.addItem(item("下一页", #selector(next), "]"))
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
    func buildPanel() {
        panel = NSWindow(contentRect: NSRect(x: 80, y: 180, width: 480, height: 650), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        panel.title = "透明文字 · GlassText"; panel.isReleasedWhenClosed = false; panel.level = .floating
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false; panel.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor, constant: 20), stack.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor, constant: -20), stack.topAnchor.constraint(equalTo: panel.contentView!.topAnchor, constant: 20)])
        stack.addArrangedSubview(NSTextField(labelWithString: "让文字浮在桌面上"))
        stack.addArrangedSubview(row([button("打开 PDF / Word / 文本", #selector(openFile)), button("显示 / 隐藏", #selector(toggleVisible))]))
        fileLabel = NSTextField(wrappingLabelWithString: "输入文字，或打开文件开始预览")
        fileLabel.preferredMaxLayoutWidth = 440; fileLabel.font = .systemFont(ofSize: 12)
        stack.addArrangedSubview(fileLabel)
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        editor = NSTextView(frame: NSRect(x: 0, y: 0, width: 430, height: 170)); editor.isRichText = false; editor.font = .systemFont(ofSize: 16); editor.string = content.text
        editor.autoresizingMask = [.width]; scroll.documentView = editor
        scroll.translatesAutoresizingMaskIntoConstraints = false; scroll.heightAnchor.constraint(equalToConstant: 170).isActive = true; scroll.widthAnchor.constraint(equalToConstant: 440).isActive = true
        stack.addArrangedSubview(scroll); stack.addArrangedSubview(button("放映输入的文字", #selector(applyText)))
        let size = NSSlider(value: 36, minValue: 16, maxValue: 96, target: self, action: #selector(changeSize(_:)))
        let color = NSColorWell(); color.color = .white; color.target = self; color.action = #selector(changeColor(_:))
        let outline = NSButton(checkboxWithTitle: "描边", target: self, action: #selector(toggleOutline(_:))); outline.state = .on
        styleRow = row([NSTextField(labelWithString: "字号"), size, NSTextField(labelWithString: "颜色"), color, outline])
        stack.addArrangedSubview(styleRow)
        removeWhite = NSButton(checkboxWithTitle: "去除 PDF 白底", target: self, action: #selector(refreshPDF)); removeWhite.state = .on
        pdfRow = row([removeWhite, NSTextField(labelWithString: "页面自动适应窗口")]); pdfRow.isHidden = true
        stack.addArrangedSubview(pdfRow)
        pinButton = NSButton(checkboxWithTitle: "窗口置顶", target: self, action: #selector(togglePin)); pinButton.state = .on
        passButton = NSButton(checkboxWithTitle: "锁定展示（鼠标穿透）", target: self, action: #selector(togglePass))
        stack.addArrangedSubview(row([pinButton, passButton, button("重置位置", #selector(resetPosition))]))
        status = NSTextField(labelWithString: "文字模式")
        stack.addArrangedSubview(row([button("← 上一页", #selector(previous)), button("下一页 →", #selector(next)), status]))
        let hint = NSTextField(wrappingLabelWithString: "调整模式：拖动内容移动，拖动右下角缩放。锁定后边框隐藏，鼠标可操作下方应用。Word 仅提取文字；保留版式请先导出 PDF。")
        hint.font = .systemFont(ofSize: 11); hint.textColor = .secondaryLabelColor; hint.preferredMaxLayoutWidth = 440; stack.addArrangedSubview(hint)
        hotkeyLabel = NSTextField(labelWithString: ""); hotkeyLabel.font = .systemFont(ofSize: 11); stack.addArrangedSubview(hotkeyLabel)
        panel.makeKeyAndOrderFront(nil)
    }
    @objc func toggleOutline(_ sender: NSButton) { content.outlined = sender.state == .on }
    @objc func refreshPDF() { render() }
    @objc func showPanel() { panel.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func togglePin() { overlay.level = pinButton.state == .on ? .floating : .normal }
    @objc func togglePass() { setLocked(!locked) }
    @objc func toggleVisible() { if overlay.isVisible { overlay.orderOut(nil) } else { overlay.orderFrontRegardless() } }
    @objc func resetPosition() { placeWindows(); recover() }
    @objc func changeSize(_ sender: NSSlider) { content.fontSize = CGFloat(sender.doubleValue); reflow() }
    @objc func changeColor(_ sender: NSColorWell) { content.ink = sender.color }
    @objc func applyText() {
        loadGeneration += 1; pdf = nil; page = 0; pageStarts = []; sourceText = editor.string
        committedLabel = "输入文字 · 纯文字展示"; fileLabel.stringValue = committedLabel; paginate(sourceText); overlay.orderFrontRegardless()
    }
    func paginate(_ text: String) {
        let anchor = pageStarts.indices.contains(page) ? pageStarts[page] : 0
        let width = content.readingArea.width, height = content.readingArea.height
        let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = 10
        let storage = NSTextStorage(string: text, attributes: [.font: NSFont.systemFont(ofSize: content.fontSize, weight: .medium), .paragraphStyle: paragraph])
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
    @objc func previous() { page = max(0, page-1); render() }
    @objc func next() { page = min((pdf?.pageCount ?? textPages.count)-1, page+1); page = max(0, page); render() }
    func render() {
        styleRow.isHidden = pdf != nil; pdfRow.isHidden = pdf == nil
        if let pdf = pdf, let source = pdf.page(at: page) {
            let thumbnail = source.thumbnail(of: NSSize(width: 1800, height: 1800), for: .mediaBox)
            guard let tiff = thumbnail.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let cg = bitmap.cgImage else { return }
            let w = cg.width, h = cg.height
            var pixels = [UInt8](repeating: 0, count: w*h*4)
            pixels.withUnsafeMutableBytes { bytes in
                guard let ctx = CGContext(data: bytes.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w*4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
                ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
                let p = bytes.bindMemory(to: UInt8.self)
                for i in stride(from: 0, to: p.count, by: 4) {
                    let white = removeWhite.state == .on ? min(p[i], min(p[i+1], p[i+2])) : 0
                    p[i] -= white; p[i+1] -= white; p[i+2] -= white; p[i+3] = 255-white
                }
                if let result = ctx.makeImage() { content.pageImage = NSImage(cgImage: result, size: thumbnail.size) }
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
    static func read(_ url: URL) throws -> Loaded {
        func failure(_ message: String) -> NSError { NSError(domain: "GlassText", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
        if url.pathExtension.lowercased() == "pdf" {
            guard let document = PDFDocument(url: url) else { throw failure("无法读取 PDF，文件可能已损坏。") }
            guard !document.isLocked else { throw failure("PDF 已加密，请解锁后重新打开。") }
            guard document.pageCount > 0 else { throw failure("PDF 没有可显示的页面。") }
            return .pdf(document)
        }
        let text: String
        if ["doc", "docx", "rtf"].contains(url.pathExtension.lowercased()) {
            let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/textutil")
            process.arguments = ["-convert", "txt", "-stdout", url.path]
            let output = Pipe(); process.standardOutput = output; process.standardError = FileHandle.nullDevice
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
            guard process.terminationStatus == 0, let converted = String(data: data, encoding: .utf8) else { throw failure("文档转换失败，请检查文件是否损坏或加密。") }
            text = converted
        } else { text = try String(contentsOf: url) }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw failure("未找到可显示的文字。图片文档请先导出 PDF。") }
        return .text(text)
    }
    func load(_ url: URL) {
        loadGeneration += 1; let generation = loadGeneration
        fileLabel.stringValue = "正在读取：" + url.lastPathComponent
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try App.read(url) }
            DispatchQueue.main.async {
                guard generation == self.loadGeneration else { return }
                switch result {
                case .success(let loaded):
                    self.page = 0; self.pageStarts = []
                    switch loaded {
                    case .pdf(let document): self.pdf = document; self.render()
                    case .text(let text):
                        self.pdf = nil; self.editor.string = text; self.sourceText = text; self.paginate(text)
                    }
                    self.fileLabel.stringValue = url.lastPathComponent + (self.pdf == nil ? " · 纯文字展示" : " · 保留版式")
                    self.committedLabel = self.fileLabel.stringValue
                    self.overlay.orderFrontRegardless()
                case .failure(let error):
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
