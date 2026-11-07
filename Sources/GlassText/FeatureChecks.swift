import AppKit
import PDFKit

extension App {
    func featureChecks(directory: URL, docx: URL) {
        let start = Date()
        precondition(brandIcon != nil && brandIcon!.isValid, "Bundled app artwork is missing")
        func iconPixels(_ image: NSImage) -> [UInt8] {
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 64, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
            NSGraphicsContext.current?.cgContext.clear(NSRect(x: 0, y: 0, width: 64, height: 64))
            image.draw(in: NSRect(x: 0, y: 0, width: 64, height: 64))
            NSGraphicsContext.restoreGraphicsState()
            return Array(UnsafeBufferPointer(start: bitmap.bitmapData!, count: bitmap.bytesPerRow * bitmap.pixelsHigh))
        }
        let actualIcon = iconPixels(NSApp.applicationIconImage), expectedIcon = iconPixels(brandIcon!)
        precondition(actualIcon.count == expectedIcon.count)
        // AppKit can copy and colour-convert the image when assigning it to the Dock.
        let averageDifference = zip(actualIcon, expectedIcon).reduce(0.0) { $0 + abs(Double($1.0) - Double($1.1)) } / Double(actualIcon.count)
        precondition(averageDifference < 2, "Dock artwork differs from bundled icon")
        print("PASS: Dock artwork matches bundled icon (mean channel difference \(averageDifference))")
        editor.string = String(repeating: "缩放锁定验证。\n",count: 100); applyText()
        let beforeZoom = content.zoom; zoomIn(); precondition(content.zoom > beforeZoom)
        resetZoom(); precondition(content.zoom == 1)
        lockPaging.state = .on; lockZoom.state = .on; setLocked(true)
        precondition(unlockPanel?.isVisible == true && overlay.ignoresMouseEvents)
        precondition(unlockPanel?.ignoresMouseEvents == false)
        precondition(unlockPanel?.parent === overlay)
        precondition(unlockButton?.title == "解锁 · 返回调整")
        precondition(lockedPromptButton?.isEnabled == false)
        let originalFrame = overlay.frame
        overlay.setFrameOrigin(NSPoint(x: originalFrame.minX + 20, y: originalFrame.minY))
        updateUnlockButton()
        let screenFrame = (overlay.screen ?? NSScreen.main)!.visibleFrame
        precondition(screenFrame.contains(unlockPanel!.frame))
        overlay.setFrame(originalFrame, display: true)
        toggleVisible(); precondition(unlockPanel?.isVisible == false)
        toggleVisible(); precondition(unlockPanel?.isVisible == true)
        unlockButton?.performClick(nil)
        precondition(!locked && !overlay.ignoresMouseEvents && unlockPanel?.isVisible == false)
        setLocked(true)
        let lockedPage = page; next(); zoomIn(); precondition(page == lockedPage && content.zoom == 1)
        lockPaging.state = .off; lockZoom.state = .off; lockOptionsChanged(); next(); zoomIn(); precondition(page > lockedPage && content.zoom > 1)
        setLocked(false); resetZoom()

        if FileManager.default.isExecutableFile(atPath: "/Applications/LibreOffice.app/Contents/MacOS/soffice") {
            if case .pdf(let document) = try! App.read(docx, preserveLayout: true) { precondition(document.pageCount > 0 && !(document.string ?? "").isEmpty) } else { preconditionFailure("Word layout conversion failed") }
        }
        let cancelled = ImportJob(); cancelled.cancel()
        do { _ = try App.read(docx, job: cancelled); preconditionFailure("Cancelled import ran") } catch {}
        let timeout = ImportJob()
        do { try timeout.run(URL(fileURLWithPath: "/bin/sleep"), arguments: ["5"], output: directory.appendingPathComponent("timeout.txt"), timeout: 0.1); preconditionFailure("Timeout not enforced") } catch { precondition(error as? ImportFailure == .timeout) }
        render()
        let clamped = App.clamped(NSRect(x: 3000, y: -500, width: 800, height: 800), to: NSRect(x: 0,y: 0,width: 600,height: 400))
        precondition(clamped == NSRect(x: 0,y: 0,width: 600,height: 400))
        editor.string = String(repeating: "滚动提词与分页回归检查。\n", count: 500)
        let paginationStart = Date(); applyText()
        let paginationTime = Date().timeIntervalSince(paginationStart)
        pageField.stringValue = "2"; jumpPage(); precondition(page == 1)
        overlayPromptButton.performClick(nil); precondition(content.continuous && countdownRemaining == 3)
        precondition(promptButton.title == "暂停提词" && overlayPromptButton.title == "暂停提词")
        overlayPromptButton.performClick(nil); precondition(timer == nil && content.countdown.isEmpty)
        setLocked(true); lockedPromptButton?.performClick(nil)
        precondition(timer != nil && locked && overlay.ignoresMouseEvents)
        precondition(countdownRemaining == 0 && content.countdown.isEmpty)
        restartPrompt(); precondition(countdownRemaining == 3 && content.scrollOffset == 0)
        for _ in 0..<3 { lastTick = Date(timeIntervalSinceNow: -1.1); tickPrompt() }
        precondition(countdownRemaining == 0 && content.countdown.isEmpty)
        lastTick = Date(timeIntervalSinceNow: -0.05); tickPrompt(); precondition(content.scrollOffset > 0)
        let pausedOffset = content.scrollOffset
        lockedPromptButton?.performClick(nil); precondition(timer == nil && content.scrollOffset == pausedOffset)
        precondition(lockedPromptButton?.title == "继续提词" && overlayPromptButton.title == "继续提词")
        lockedPromptButton?.performClick(nil)
        precondition(timer != nil && content.scrollOffset == pausedOffset && countdownRemaining == 0 && content.countdown.isEmpty)
        lastTick = Date(timeIntervalSinceNow: -0.05); tickPrompt(); precondition(content.scrollOffset > pausedOffset)
        let resumedOffset = content.scrollOffset
        lockPaging.state = .on; lockOptionsChanged()
        precondition(timer == nil && lockedPromptButton?.isEnabled == false && !overlayPromptButton.isEnabled)
        togglePrompt(); precondition(timer == nil)
        lockPaging.state = .off; lockOptionsChanged(); lockedPromptButton?.performClick(nil)
        precondition(timer != nil && content.scrollOffset == resumedOffset && countdownRemaining == 0)
        content.scrollOffset = max(0, promptHeight-content.readingArea.height)
        countdownRemaining = 0; tickPrompt(); precondition(timer == nil)
        lockedPromptButton?.performClick(nil); precondition(timer != nil && content.scrollOffset == 0 && countdownRemaining == 3)
        pausePrompt(); setLocked(false); exitPrompt(); render()
        pdf = PDFDocument(); refreshInteractionPolicy(); overlayPromptButton.performClick(nil)
        precondition(timer == nil && !overlayPromptButton.isEnabled && lockedPromptButton?.isEnabled == false)
        pdf = nil; refreshInteractionPolicy()
        let promptMenu = NSApp.mainMenu?.items.first?.submenu?.items.first { $0.action == #selector(togglePrompt) }
        precondition(promptMenu?.keyEquivalent == "p" && promptMenu?.keyEquivalentModifierMask == [.command, .shift])
        newSnapshot(); precondition(extras.count == 1)
        setLocked(true); precondition(extras[0].ignoresMouseEvents)
        setLocked(false); precondition(!extras[0].ignoresMouseEvents); closeSnapshots(); precondition(extras.isEmpty)
        // Use an isolated suite; never alter the user's saved settings during validation.
        allowTestPersistence = true
        fontSlider.doubleValue = 42; changeSize(fontSlider); spacingSlider.doubleValue = 17; styleChanged()
        page = min(2,textPages.count-1); saveState(); let expectedPage = page
        content.fontSize = 18; spacingSlider.doubleValue = 1
        restoreState()
        precondition(content.fontSize == 42 && content.lineSpacing == 17 && page == expectedPage)
        sectionPicker.selectedSegment = 1; switchSection(); precondition(sections[0].isHidden && !sections[1].isHidden)
        useExample(); showGuide(); precondition(guide != nil && guideStep == 0)
        if let root = guide?.contentView {
            root.layoutSubtreeIfNeeded()
            if let bitmap = root.bitmapImageRepForCachingDisplay(in: root.bounds) {
                root.cacheDisplay(in: root.bounds,to: bitmap)
                try? bitmap.representation(using: .png,properties: [:])?.write(to: URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("dist/guide-preview.png"))
            }
        }
        nextGuide(); nextGuide(); nextGuide(); precondition(guideStep == 3 && guidePicture.image != nil && guidePicture.boxes.count == 2)
        finishGuide(); precondition(guide == nil && !locked)
        allowTestPersistence = false
        defaults.removePersistentDomain(forName: testSuite)
        print(String(format: "PASS: Word layout PDF, cancellation, process timeout, PDF cache, screen recovery, page jump, prompter countdown/scroll/pause, multiple overlays, settings round-trip. Pagination %.3fs; feature checks %.3fs", paginationTime, Date().timeIntervalSince(start)))
    }
}
