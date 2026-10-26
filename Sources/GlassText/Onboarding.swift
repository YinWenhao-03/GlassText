import AppKit

final class GuideSurface: NSView { override func draw(_ dirtyRect: NSRect) { NSColor.windowBackgroundColor.setFill(); dirtyRect.fill() } }

extension App {
    @objc func showGuide() {
        guard guide == nil else { guide?.makeKeyAndOrderFront(nil); return }
        pausePrompt(); guideOriginalLock = locked; guideOriginalSection = sectionPicker.selectedSegment; setLocked(false)
        let window = NSWindow(contentRect: NSRect(x: 0,y: 0,width: 780,height: 600),styleMask: [.titled],backing: .buffered,defer: false)
        window.contentView = GuideSurface(frame: NSRect(x: 0,y: 0,width: 780,height: 600))
        window.title = "新手引导 · 跟着红框操作"; window.isReleasedWhenClosed = false; window.level = .floating; guide = window; guideStep = 0
        guideProgress = note("")
        guideTitle = NSTextField(labelWithString: ""); guideTitle.font = .systemFont(ofSize: 21,weight: .semibold)
        guideBody = NSTextField(wrappingLabelWithString: ""); guideBody.font = .systemFont(ofSize: 14); guideBody.preferredMaxLayoutWidth = 284
        guideBody.widthAnchor.constraint(equalToConstant: 284).isActive = true; guideBody.heightAnchor.constraint(equalToConstant: 240).isActive = true
        guideNext = button("下一步",#selector(nextGuide)); guideNext.bezelStyle = .rounded; guideNext.keyEquivalent = "\r"
        guidePicture = TutorialImage(); guidePicture.translatesAutoresizingMaskIntoConstraints = false; window.contentView!.addSubview(guidePicture)
        NSLayoutConstraint.activate([guidePicture.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor,constant: 16),guidePicture.topAnchor.constraint(equalTo: window.contentView!.topAnchor,constant: 16),guidePicture.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor,constant: -16),guidePicture.widthAnchor.constraint(equalToConstant: 420)])
        let stack = column([guideProgress,guideTitle,guideBody,note("左侧是当前应用界面的截图。红框编号与说明一一对应。"),row([button("上一步",#selector(previousGuide)),guideNext]),button("关闭引导",#selector(finishGuide))],spacing: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false; window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: guidePicture.trailingAnchor,constant: 24),stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor,constant: 30)])
        updateGuide(); window.center(); window.makeKeyAndOrderFront(nil)
    }
    func updateGuide() {
        guideProgress.stringValue = "第 \(guideStep+1) 步，共 4 步"
        sectionPicker.selectedSegment = guideStep == 1 ? 1 : 0; switchSection()
        let titles = ["放入你要看的内容","调整到看得清","移动和调整大小","锁定与恢复"]
        let appearance = pdf == nil ? "② 拖动字号滑块调整大小；上方可以选择白字、黑字或其他颜色。建议保留描边。" : "② 当前是 PDF，可开启或关闭去白底，并调整去白强度。PDF 保留原页布局，不使用文字字号设置。"
        let bodies = [
            "① 点击“打开文件…”，选择 PDF、Word 或文本。也可以把文件拖进主界面。\n\n② 在输入框编辑后，点击“显示这段文字”才会更新展示内容。",
            "① 选择顶部“外观”页面。\n\n"+appearance+"\n\n行距、透明度和底板藏在“更多外观设置…”中。",
            "① 未锁定时，按住展示文字拖动，移动到合适的位置。\n\n② 拖动右下角的缩放把手，改变展示窗口大小。\n\n想重来时，打开“设置…”并点击“重置窗口”。",
            "① 点击“锁定展示”，边框隐藏，鼠标可以操作下方应用。再次点击“返回调整”即可解锁。\n\n② 打开“设置…”查看全局恢复键，默认 ⌃⌥⌘G。\n\n也可从菜单栏“透 → 恢复操作”找回窗口。"
        ]
        guideTitle.stringValue = titles[guideStep]; guideBody.stringValue = bodies[guideStep]
        guideNext.title = guideStep == 3 ? "完成，开始使用" : "下一步"
        captureGuideStep()
    }
    @objc func nextGuide() { if guideStep == 3 { finishGuide(); return }; guideStep += 1; updateGuide() }
    @objc func previousGuide() { guideStep = max(0,guideStep-1); updateGuide() }
    @objc func finishGuide() {
        guide?.orderOut(nil); guide = nil; setLocked(guideOriginalLock)
        sectionPicker.selectedSegment = guideOriginalSection; switchSection()
        if !testing { defaults.set(true,forKey: "onboardingComplete") }
    }
}
