import AppKit
import PDFKit
import UniformTypeIdentifiers

final class ContentView: NSView {
    var text = "透明文字\n\n在控制面板输入文字，或打开 PDF / Word 文件。\n拖动文字区域可以移动窗口。" { didSet { needsDisplay = true } }
    var fontSize: CGFloat = 36 { didSet { needsDisplay = true } }
    var ink = NSColor.white { didSet { needsDisplay = true } }
    var pageImage: NSImage? { didSet { needsDisplay = true } }
    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill(); dirtyRect.fill(using: .copy)
        let area = bounds.insetBy(dx: 24, dy: 24)
        if let image = pageImage {
            let ratio = min(area.width / image.size.width, area.height / image.size.height)
            let size = NSSize(width: image.size.width * ratio, height: image.size.height * ratio)
            image.draw(in: NSRect(x: area.midX-size.width/2, y: area.midY-size.height/2, width: size.width, height: size.height), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        } else {
            let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = 10
            (text as NSString).draw(in: area, withAttributes: [.font: NSFont.systemFont(ofSize: fontSize, weight: .medium), .foregroundColor: ink, .paragraphStyle: paragraph])
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        buildMenu()
        overlay = NSWindow(contentRect: NSRect(x: 240, y: 180, width: 900, height: 600), styleMask: [.borderless, .resizable], backing: .buffered, defer: false)
        overlay.isOpaque = false; overlay.backgroundColor = .clear; overlay.hasShadow = false
        overlay.isMovableByWindowBackground = true; overlay.level = .floating
        overlay.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        overlay.contentView = content; overlay.makeKeyAndOrderFront(nil)
        overlay.delegate = self
        buildPanel(); NSApp.activate(ignoringOtherApps: true)
        if CommandLine.arguments.contains("--self-test") { selfTest(); NSApp.terminate(nil) }
    }
    func windowDidEndLiveResize(_ notification: Notification) { if pdf == nil { paginate(editor.string) } }
    func selfTest() {
        editor.string = String(repeating: "透明文字 pagination test 中文测试。\n", count: 100)
        applyText()
        precondition(textPages.count > 1)
        precondition(textPages.joined() == editor.string)
        next(); precondition(page == 1); previous(); precondition(page == 0)
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
        print("PASS: Chinese text pagination, page navigation, click-through, window level, PDF white-background transparency and black content retention")
    }
    func item(_ title: String, _ action: Selector, _ key: String = "") -> NSMenuItem {
        let result = NSMenuItem(title: title, action: action, keyEquivalent: key); result.target = self; return result
    }
    func buildMenu() {
        let main = NSMenu(); let appItem = NSMenuItem(); main.addItem(appItem)
        let menu = NSMenu(); appItem.submenu = menu
        menu.addItem(item("显示控制面板", #selector(showPanel), "0"))
        menu.addItem(item("打开文件…", #selector(openFile), "o"))
        menu.addItem(item("切换鼠标穿透", #selector(togglePass), "i"))
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
        panel = NSWindow(contentRect: NSRect(x: 80, y: 180, width: 480, height: 540), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        panel.title = "透明文字 · GlassText"; panel.isReleasedWhenClosed = false
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false; panel.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor, constant: 20), stack.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor, constant: -20), stack.topAnchor.constraint(equalTo: panel.contentView!.topAnchor, constant: 20)])
        stack.addArrangedSubview(NSTextField(labelWithString: "让文字浮在桌面上"))
        stack.addArrangedSubview(row([button("打开 PDF / Word / 文本", #selector(openFile)), button("显示 / 隐藏", #selector(toggleVisible))]))
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        editor = NSTextView(frame: NSRect(x: 0, y: 0, width: 430, height: 170)); editor.isRichText = false; editor.font = .systemFont(ofSize: 16); editor.string = content.text
        editor.autoresizingMask = [.width]; scroll.documentView = editor
        scroll.translatesAutoresizingMaskIntoConstraints = false; scroll.heightAnchor.constraint(equalToConstant: 170).isActive = true; scroll.widthAnchor.constraint(equalToConstant: 440).isActive = true
        stack.addArrangedSubview(scroll); stack.addArrangedSubview(button("放映输入的文字", #selector(applyText)))
        let size = NSSlider(value: 36, minValue: 16, maxValue: 96, target: self, action: #selector(changeSize(_:)))
        let color = NSColorWell(); color.color = .white; color.target = self; color.action = #selector(changeColor(_:))
        stack.addArrangedSubview(row([NSTextField(labelWithString: "字号"), size, NSTextField(labelWithString: "颜色"), color]))
        pinButton = NSButton(checkboxWithTitle: "窗口置顶", target: self, action: #selector(togglePin)); pinButton.state = .on
        passButton = NSButton(checkboxWithTitle: "鼠标穿透", target: self, action: #selector(togglePass))
        stack.addArrangedSubview(row([pinButton, passButton, button("重置位置", #selector(resetPosition))]))
        status = NSTextField(labelWithString: "文字模式")
        stack.addArrangedSubview(row([button("← 上一页", #selector(previous)), button("下一页 →", #selector(next)), status]))
        let hint = NSTextField(wrappingLabelWithString: "拖动内容移动窗口，拖动边缘调整大小。鼠标穿透后，可从顶部菜单栏“透 Aa”恢复控制。PDF 去除白底；Word 以纯文字分页展示。")
        hint.font = .systemFont(ofSize: 11); hint.textColor = .secondaryLabelColor; hint.preferredMaxLayoutWidth = 440; stack.addArrangedSubview(hint)
        panel.makeKeyAndOrderFront(nil)
    }
    @objc func showPanel() { panel.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func togglePin() { overlay.level = pinButton.state == .on ? .floating : .normal }
    @objc func togglePass() { overlay.ignoresMouseEvents.toggle(); passButton.state = overlay.ignoresMouseEvents ? .on : .off }
    @objc func toggleVisible() { if overlay.isVisible { overlay.orderOut(nil) } else { overlay.orderFrontRegardless() } }
    @objc func resetPosition() { overlay.setFrame(NSRect(x: 240, y: 180, width: 900, height: 600), display: true); overlay.orderFrontRegardless() }
    @objc func changeSize(_ sender: NSSlider) { content.fontSize = CGFloat(sender.doubleValue); if pdf == nil { paginate(editor.string) } }
    @objc func changeColor(_ sender: NSColorWell) { content.ink = sender.color }
    @objc func applyText() { pdf = nil; page = 0; paginate(editor.string); overlay.orderFrontRegardless() }
    func paginate(_ text: String) {
        let width = max(100, content.bounds.width - 48), height = max(100, content.bounds.height - 48)
        let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = 10
        let storage = NSTextStorage(string: text, attributes: [.font: NSFont.systemFont(ofSize: content.fontSize, weight: .medium), .paragraphStyle: paragraph])
        let layout = NSLayoutManager(); storage.addLayoutManager(layout)
        textPages = []; var consumed = 0
        while consumed < storage.length {
            let container = NSTextContainer(containerSize: NSSize(width: width, height: height)); container.lineFragmentPadding = 0
            layout.addTextContainer(container)
            let glyphs = layout.glyphRange(for: container)
            let range = layout.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
            if range.length == 0 { break }
            textPages.append((text as NSString).substring(with: range)); consumed = NSMaxRange(range)
        }
        if textPages.isEmpty { textPages = [""] }; page = min(page, textPages.count-1); render()
    }
    @objc func previous() { page = max(0, page-1); render() }
    @objc func next() { page = min((pdf?.pageCount ?? textPages.count)-1, page+1); page = max(0, page); render() }
    func render() {
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
                    let white = min(p[i], min(p[i+1], p[i+2]))
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
        do {
            if url.pathExtension.lowercased() == "pdf" {
                guard let document = PDFDocument(url: url), !document.isLocked, document.pageCount > 0 else { throw NSError(domain: "GlassText", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法读取 PDF，请先解锁或检查文件。"]) }
                pdf = document; page = 0; render()
            } else {
                let text: String
                if ["doc", "docx", "rtf"].contains(url.pathExtension.lowercased()) {
                    let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/textutil"); process.arguments = ["-convert", "txt", "-stdout", url.path]
                    let output = Pipe(); process.standardOutput = output; process.standardError = FileHandle.nullDevice
                    try process.run(); let data = output.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
                    guard process.terminationStatus == 0, let converted = String(data: data, encoding: .utf8) else { throw NSError(domain: "GlassText", code: 2, userInfo: [NSLocalizedDescriptionKey: "Word 文件转换失败，请确认文件未加密。"]) }; text = converted
                } else { text = try String(contentsOf: url) }
                editor.string = text; applyText()
            }
            overlay.orderFrontRegardless()
        } catch { let alert = NSAlert(error: error); alert.runModal() }
    }
}
let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.run()
