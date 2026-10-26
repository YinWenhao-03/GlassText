import AppKit

final class TutorialImage: NSView {
    var image: NSImage? { didSet { needsDisplay = true } }
    var boxes: [NSRect] = [] { didSet { needsDisplay = true } }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill(); bounds.fill()
        guard let image = image else { return }
        let scale = min((bounds.width-24)/image.size.width,(bounds.height-24)/image.size.height)
        let frame = NSRect(x: (bounds.width-image.size.width*scale)/2,y: (bounds.height-image.size.height*scale)/2,width: image.size.width*scale,height: image.size.height*scale)
        image.draw(in: frame,from: .zero,operation: .sourceOver,fraction: 1,respectFlipped: true,hints: nil)
        for (index,box) in boxes.enumerated() {
            let rect = NSRect(x: frame.minX+box.minX*scale,y: frame.minY+box.minY*scale,width: box.width*scale,height: box.height*scale)
            NSColor.systemRed.setStroke(); let path = NSBezierPath(roundedRect: rect.insetBy(dx: -3,dy: -3),xRadius: 4,yRadius: 4); path.lineWidth = 2.5; path.stroke()
            let badge = NSRect(x: max(0,rect.minX-10),y: max(0,rect.minY-10),width: 22,height: 22)
            NSColor.systemRed.setFill(); NSBezierPath(ovalIn: badge).fill()
            let style = NSMutableParagraphStyle(); style.alignment = .center
            (String(index+1) as NSString).draw(in: badge.offsetBy(dx: 0,dy: 2),withAttributes: [.font: NSFont.systemFont(ofSize: 13,weight: .bold),.foregroundColor: NSColor.white,.paragraphStyle: style])
        }
    }
}
extension App {
    func captureGuideStep() {
        let root: NSView = guideStep == 2 ? content : panel.contentView!
        root.layoutSubtreeIfNeeded()
        func locate(_ title: String,_ view: NSView) -> NSView? {
            if let button = view as? NSButton,button.title == title { return button }
            for child in view.subviews { if let found = locate(title,child) { return found } }
            return nil
        }
        func rect(_ view: NSView) -> NSRect {
            let r = view.convert(view.bounds,to: root)
            return NSRect(x: r.minX,y: root.isFlipped ? r.minY : root.bounds.height-r.maxY,width: r.width,height: r.height)
        }
        if guideStep == 0 { guidePicture.boxes = [rect(locate("打开文件…",root)!),rect(locate("显示这段文字",root)!)] }
        if guideStep == 1 { guidePicture.boxes = [rect(sectionPicker),rect(pdf == nil ? fontSlider : removeWhite)] }
        if guideStep == 2 { guidePicture.boxes = [content.readingArea.insetBy(dx: 8,dy: 8),NSRect(x: root.bounds.width-30,y: root.bounds.height-30,width: 28,height: 28)] }
        if guideStep == 3 { guidePicture.boxes = [rect(passButton),rect(locate("设置…",root)!)] }
        if let bitmap = root.bitmapImageRepForCachingDisplay(in: root.bounds) {
            root.cacheDisplay(in: root.bounds,to: bitmap)
            let image = NSImage(size: root.bounds.size); image.addRepresentation(bitmap); guidePicture.image = image
        }
    }
}
