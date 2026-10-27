import AppKit

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
        precondition((unlockPanel?.contentView as? NSButton)?.title == "解锁 · 返回调整")
        let originalFrame = overlay.frame
        overlay.setFrameOrigin(NSPoint(x: originalFrame.minX + 20, y: originalFrame.minY))
        updateUnlockButton()
        let screenFrame = (overlay.screen ?? NSScreen.main)!.visibleFrame
        precondition(screenFrame.contains(unlockPanel!.frame))
        overlay.setFrame(originalFrame, display: true)
        toggleVisible(); precondition(unlockPanel?.isVisible == false)
        toggleVisible(); precondition(unlockPanel?.isVisible == true)
        (unlockPanel?.contentView as? NSButton)?.performClick(nil)
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
        togglePrompt(); precondition(content.continuous && countdownRemaining == 3)
        for _ in 0..<3 { lastTick = Date(timeIntervalSinceNow: -1.1); tickPrompt() }
        precondition(countdownRemaining == 0 && content.countdown.isEmpty)
        lastTick = Date(timeIntervalSinceNow: -0.05); tickPrompt(); precondition(content.scrollOffset > 0)
        pausePrompt(); precondition(timer == nil); exitPrompt(); render()
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
