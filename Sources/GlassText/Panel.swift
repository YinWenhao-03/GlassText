import AppKit

final class DropSurface: NSView {
    var receive: ((URL) -> Void)?
    override init(frame: NSRect) { super.init(frame: frame); registerForDraggedTypes([.fileURL]) }
    required init?(coder: NSCoder) { fatalError() }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = (sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL])?.first else { return false }
        receive?(url); return true
    }
}
extension App {
    func column(_ views: [NSView], spacing: CGFloat = 16) -> NSStackView {
        let stack = NSStackView(views: views); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = spacing
        return stack
    }
    func note(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text); label.font = .systemFont(ofSize: 12); label.textColor = .secondaryLabelColor; label.preferredMaxLayoutWidth = 392; return label
    }
    func labeled(_ title: String, _ control: NSView) -> NSStackView {
        let label = NSTextField(labelWithString: title); label.widthAnchor.constraint(equalToConstant: 78).isActive = true
        if control is NSSlider { control.widthAnchor.constraint(equalToConstant: 280).isActive = true }
        return row([label, control])
    }
    func buildPanel() {
        panel = NSWindow(contentRect: NSRect(x: 80, y: 180, width: 440, height: 650), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        panel.title = "透明文字"; panel.isReleasedWhenClosed = false; panel.level = .floating
        let surface = DropSurface(frame: panel.contentView!.bounds); surface.receive = { [weak self] in self?.load($0) }; panel.contentView = surface
        let heading = NSTextField(labelWithString: "透明文字"); heading.font = .systemFont(ofSize: 22, weight: .semibold)
        let symbol = NSImageView(); symbol.image = brandIcon ?? NSApp.applicationIconImage
        symbol.widthAnchor.constraint(equalToConstant: 42).isActive = true; symbol.heightAnchor.constraint(equalToConstant: 42).isActive = true
        sectionPicker = NSSegmentedControl(labels: ["内容", "外观", "提词"], trackingMode: .selectOne, target: self, action: #selector(switchSection)); sectionPicker.selectedSegment = 0
        sectionPicker.segmentStyle = .rounded; sectionPicker.widthAnchor.constraint(equalToConstant: 392).isActive = true
        let header = column([row([symbol, column([heading, note("把资料放在手边")], spacing: 2)]), sectionPicker])
        header.translatesAutoresizingMaskIntoConstraints = false; surface.addSubview(header)
        NSLayoutConstraint.activate([header.topAnchor.constraint(equalTo: surface.topAnchor, constant: 20), header.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 24)])

        // Content: one obvious import action and one text action.
        let open = button("打开文件…", #selector(openFile)); open.bezelStyle = .rounded
        fileLabel = note("PDF、Word、TXT，也可以拖到这里")
        cancelButton = button("取消读取", #selector(cancelLoad)); cancelButton.isHidden = true
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        editor = NSTextView(frame: NSRect(x: 0,y: 0,width: 388,height: 150)); editor.isRichText = false; editor.font = .systemFont(ofSize: 15); editor.string = content.text; editor.autoresizingMask = [.width]
        scroll.documentView = editor; scroll.widthAnchor.constraint(equalToConstant: 392).isActive = true; scroll.heightAnchor.constraint(equalToConstant: 150).isActive = true
        let contentSection = column([row([open, cancelButton]), fileLabel, scroll, row([button("显示这段文字", #selector(applyText)), button("使用示例", #selector(useExample))])], spacing: 12)

        // Appearance: common choices first; detailed typography stays collapsed.
        fontSlider = NSSlider(value: 36,minValue: 16,maxValue: 96,target: self,action: #selector(changeSize(_:)))
        colorWell = NSColorWell(); colorWell.color = .white; colorWell.target = self; colorWell.action = #selector(changeColor(_:))
        outlineBox = NSButton(checkboxWithTitle: "描边，让文字更清楚", target: self, action: #selector(toggleOutline(_:))); outlineBox.state = .on
        styleRow = column([row([button("白字", #selector(whiteText)), button("黑字", #selector(blackText)), colorWell]), labeled("字号",fontSlider), outlineBox])
        removeWhite = NSButton(checkboxWithTitle: "去除 PDF 白底", target: self, action: #selector(refreshPDF)); removeWhite.state = .on
        whiteSlider = NSSlider(value: 1,minValue: 0,maxValue: 1,target: self,action: #selector(refreshPDF))
        pdfRow = column([removeWhite, labeled("去白强度", whiteSlider), note("图片中的白色也会受影响，可关闭查看原页。")]); pdfRow.isHidden = true
        weightPicker = NSPopUpButton(); weightPicker.addItems(withTitles: ["常规","中等","粗体"]); weightPicker.selectItem(at: 1); weightPicker.target = self; weightPicker.action = #selector(styleChanged)
        alignPicker = NSPopUpButton(); alignPicker.addItems(withTitles: ["左对齐","居中","右对齐"]); alignPicker.target = self; alignPicker.action = #selector(styleChanged)
        spacingSlider = NSSlider(value: 10,minValue: 0,maxValue: 32,target: self,action: #selector(styleChanged))
        textLayoutRow = column([row([weightPicker,alignPicker]), labeled("行距",spacingSlider)],spacing: 12)
        opacitySlider = NSSlider(value: 1,minValue: 0.15,maxValue: 1,target: self,action: #selector(styleChanged))
        backdropSlider = NSSlider(value: 0,minValue: 0,maxValue: 0.85,target: self,action: #selector(styleChanged))
        appearanceDetails = column([textLayoutRow,labeled("内容不透明度",opacitySlider),labeled("背景底板",backdropSlider)],spacing: 12); appearanceDetails.isHidden = true
        panRow = row([button("← 平移",#selector(panLeft)),button("↑",#selector(panUp)),button("↓",#selector(panDown)),button("→",#selector(panRight))]); panRow.isHidden = true
        let appearance = column([styleRow,pdfRow,panRow,button("更多外观设置…",#selector(toggleAppearance)),appearanceDetails])

        promptButton = button("开始提词",#selector(togglePrompt))
        speedSlider = NSSlider(value: 30,minValue: 5,maxValue: 100,target: self,action: #selector(changeSpeed(_:)))
        let prompter = column([NSTextField(labelWithString: "解放双手，让文字慢慢向上滚动"),note("开始前倒计时 3 秒。随时可以暂停，继续时保留位置。仅支持纯文字。"),row([promptButton,button("从头开始",#selector(restartPrompt))]),labeled("滚动速度",speedSlider),note("左慢右快 · 5–100 点/秒")],spacing: 20)
        sections = [contentSection,appearance,prompter]
        let body = NSView(); body.translatesAutoresizingMaskIntoConstraints = false; surface.addSubview(body)
        NSLayoutConstraint.activate([body.topAnchor.constraint(equalTo: header.bottomAnchor,constant: 22),body.leadingAnchor.constraint(equalTo: surface.leadingAnchor,constant: 24),body.trailingAnchor.constraint(equalTo: surface.trailingAnchor,constant: -24),body.heightAnchor.constraint(equalToConstant: 310)])
        for section in sections {
            section.translatesAutoresizingMaskIntoConstraints = false; body.addSubview(section)
            NSLayoutConstraint.activate([section.topAnchor.constraint(equalTo: body.topAnchor),section.leadingAnchor.constraint(equalTo: body.leadingAnchor),section.trailingAnchor.constraint(lessThanOrEqualTo: body.trailingAnchor)])
        }
        switchSection()

        status = NSTextField(labelWithString: "1 / 1"); status.font = .monospacedDigitSystemFont(ofSize: 12,weight: .regular)
        pageField = NSTextField(string: "1"); pageField.widthAnchor.constraint(equalToConstant: 38).isActive = true; pageField.target = self; pageField.action = #selector(jumpPage); pageField.toolTip = "输入页码并按回车"
        pinButton = NSButton(checkboxWithTitle: "置顶",target: self,action: #selector(togglePin)); pinButton.state = .on
        passButton = button("锁定展示",#selector(togglePass)); passButton.bezelStyle = .rounded; passButton.bezelColor = .controlAccentColor
        let divider = NSBox(); divider.boxType = .separator; divider.widthAnchor.constraint(equalToConstant: 392).isActive = true
        let back = button("←",#selector(previous)), forward = button("→",#selector(next))
        let minus = button("−",#selector(zoomOut)), plus = button("＋",#selector(zoomIn)), fit = button("重置",#selector(resetZoom))
        zoomLabel = NSTextField(labelWithString: "100%"); zoomLabel.font = .monospacedDigitSystemFont(ofSize: 12,weight: .regular)
        pagingControls = [back,forward,pageField]; zoomControls = [minus,plus,fit,fontSlider]
        lockSummary = note("调整中 · 可移动窗口")
        let footer = column([divider,lockSummary,row([back,status,forward,pageField,button("显示 / 隐藏",#selector(toggleVisible))]),row([NSTextField(labelWithString: "缩放"),minus,zoomLabel,plus,fit]),row([pinButton,button("设置…",#selector(showPreferences)),button("新手引导",#selector(showGuide)),passButton])],spacing: 12)
        footer.translatesAutoresizingMaskIntoConstraints = false; surface.addSubview(footer)
        NSLayoutConstraint.activate([footer.leadingAnchor.constraint(equalTo: surface.leadingAnchor,constant: 24),footer.bottomAnchor.constraint(equalTo: surface.bottomAnchor,constant: -20)])
        buildPreferences(); refreshInteractionPolicy(); panel.makeKeyAndOrderFront(nil)
    }
    @objc func switchSection() { for (index,section) in sections.enumerated() { section.isHidden = index != sectionPicker.selectedSegment } }
    @objc func toggleAppearance() { appearanceDetails.isHidden.toggle() }
    @objc func whiteText() { colorWell.color = .white; changeColor(colorWell) }
    @objc func blackText() { colorWell.color = .black; changeColor(colorWell) }
    @objc func useExample() { editor.string = "把资料放在手边\n\n拖动这段文字，找到舒服的位置。\n\n点击“锁定展示”，就能继续操作下面的应用。\n\n想调整时，从菜单栏“透”恢复。"; applyText() }
    func buildPreferences() {
        preferences = NSWindow(contentRect: NSRect(x: 100,y: 100,width: 440,height: 420),styleMask: [.titled,.closable],backing: .buffered,defer: false); preferences.title = "更多设置"; preferences.isReleasedWhenClosed = false; preferences.level = .floating
        modePicker = NSPopUpButton(); modePicker.addItems(withTitles: ["提取文字","保留版式（需 LibreOffice）"]); modePicker.target = self; modePicker.action = #selector(savePreferences)
        screenPicker = NSPopUpButton(); screenPicker.target = self; screenPicker.action = #selector(moveScreen)
        keyPicker = NSPopUpButton(); keyPicker.addItems(withTitles: ["G","T","R"]); keyPicker.target = self; keyPicker.action = #selector(changeKey)
        hotkeyLabel = note("")
        lockPaging = NSButton(checkboxWithTitle: "锁定展示时，禁止翻页与提词",target: self,action: #selector(lockOptionsChanged))
        lockZoom = NSButton(checkboxWithTitle: "锁定展示时，禁止放大缩小",target: self,action: #selector(lockOptionsChanged))
        let stack = column([lockPaging,lockZoom,note("未勾选时，锁定后仍可从控制面板翻页和缩放。展示窗口始终保持鼠标穿透。"),labeled("Word 导入",modePicker),labeled("显示器",screenPicker),row([NSTextField(labelWithString: "全局恢复 ⌃⌥⌘"),keyPicker]),hotkeyLabel,row([button("重置窗口",#selector(resetPosition)),button("新建页副本",#selector(newSnapshot)),button("关闭副本",#selector(closeSnapshots))]),button("查看更新",#selector(checkUpdates))])
        stack.translatesAutoresizingMaskIntoConstraints = false; preferences.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: preferences.contentView!.leadingAnchor,constant: 24),stack.topAnchor.constraint(equalTo: preferences.contentView!.topAnchor,constant: 24)])
    }
    @objc func savePreferences() { saveState() }
    @objc func showPreferences() { preferences.center(); preferences.makeKeyAndOrderFront(nil) }
}
