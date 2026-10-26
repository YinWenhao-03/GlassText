import AppKit

extension App {
    var canPage: Bool { !locked || lockPaging?.state != .on }
    var canZoom: Bool { !locked || lockZoom?.state != .on }
    func refreshInteractionPolicy() {
        pagingControls.forEach { $0.isEnabled = canPage }
        zoomControls.forEach { $0.isEnabled = canZoom }
        promptButton?.isEnabled = canPage && pdf == nil
        zoomLabel?.stringValue = "\(Int((content.zoom*100).rounded()))%"
        lockSummary?.stringValue = locked ? "已锁定 · 翻页\(canPage ? "允许" : "禁止") · 缩放\(canZoom ? "允许" : "禁止")" : "调整中 · 拖动内容移动窗口"
        if let panRow = panRow { panRow.arrangedSubviews.compactMap { $0 as? NSControl }.forEach { $0.isEnabled = canZoom } }
        if !canPage { pausePrompt() }
    }
    @objc func lockOptionsChanged() { refreshInteractionPolicy(); saveState() }
    func setZoom(_ value: CGFloat) {
        guard canZoom else { return }
        content.zoom = min(3,max(0.5,value)); content.pan = .zero; panRow.isHidden = pdf == nil || content.zoom <= 1; reflow(); refreshInteractionPolicy(); saveState()
    }
    @objc func zoomIn() { setZoom(content.zoom+0.1) }
    @objc func zoomOut() { setZoom(content.zoom-0.1) }
    @objc func resetZoom() { setZoom(1) }
    func panBy(_ x: CGFloat,_ y: CGFloat) {
        guard canZoom, let image = content.pageImage, content.zoom > 1 else { return }
        let area = content.readingArea, ratio = min(content.readingArea.width/image.size.width,content.readingArea.height/image.size.height)*content.zoom
        let limitX = max(0,(image.size.width*ratio-area.width)/2), limitY = max(0,(image.size.height*ratio-area.height)/2)
        content.pan = NSPoint(x: min(limitX,max(-limitX,content.pan.x+x)),y: min(limitY,max(-limitY,content.pan.y+y)))
    }
    @objc func panLeft() { panBy(60,0) }
    @objc func panRight() { panBy(-60,0) }
    @objc func panUp() { panBy(0,60) }
    @objc func panDown() { panBy(0,-60) }
}
