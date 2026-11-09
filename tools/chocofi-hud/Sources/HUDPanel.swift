import AppKit

// Floating, click-through panel that shows the active layer's map and armed one-shots.
final class HUDPanel: NSPanel {
    let board = BoardView()

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 420, height: 230),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        alphaValue = 0

        let blur = NSVisualEffectView()
        blur.material = .hudWindow
        blur.state = .active
        blur.blendingMode = .behindWindow
        // a mask image (not a layer corner radius) so the window shadow follows the rounded shape
        blur.maskImage = HUDPanel.roundedMask(radius: 16)
        contentView = blur
        board.translatesAutoresizingMaskIntoConstraints = false
        blur.addSubview(board)
        NSLayoutConstraint.activate([
            board.leadingAnchor.constraint(equalTo: blur.leadingAnchor),
            board.trailingAnchor.constraint(equalTo: blur.trailingAnchor),
            board.topAnchor.constraint(equalTo: blur.topAnchor),
            board.bottomAnchor.constraint(equalTo: blur.bottomAnchor),
        ])
    }

    func show(_ state: BoardState, position: String) {
        board.state = state
        let size = board.preferredSize
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let f = screen?.visibleFrame {
            let margin: CGFloat = 24
            let origin: NSPoint
            switch position {
            case "bottomRight": origin = NSPoint(x: f.maxX - size.width - margin, y: f.minY + margin)
            case "topRight": origin = NSPoint(x: f.maxX - size.width - margin, y: f.maxY - size.height - margin)
            default: origin = NSPoint(x: f.midX - size.width / 2, y: f.minY + margin * 2)
            }
            setFrame(NSRect(origin: origin, size: size), display: true)
        }
        board.needsDisplay = true
        orderFrontRegardless()
        invalidateShadow()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.08; animator().alphaValue = 1 }
    }

    static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }

    func hide() {
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.15; animator().alphaValue = 0 },
                                             completionHandler: { [weak self] in
            if self?.alphaValue == 0 { self?.orderOut(nil) }
        })
    }
}

final class BoardView: NSView {
    var state = BoardState()
    private let unit: CGFloat = 30, cap: CGFloat = 26, pull: CGFloat = 1.4, pad: CGFloat = 16, header: CGFloat = 40

    override var isFlipped: Bool { true }
    private var showsMap: Bool { state.layer != 0 }

    var preferredSize: NSSize {
        if !showsMap { return NSSize(width: 220, height: header + 8) }
        let w = (12 - pull) * unit + unit + pad * 2
        let h = 4.1 * unit + unit + pad + header + 10
        return NSSize(width: w, height: h)
    }

    override func draw(_ dirtyRect: NSRect) {
        let ink = NSColor.labelColor, muted = NSColor.secondaryLabelColor
        let accent = NSColor.controlAccentColor, orange = NSColor.systemOrange

        // header: layer name, then armed one-shot modifiers as pills
        var x = pad
        let title = showsMap ? Keymap.layerNames[state.layer] : "ONE-SHOT"
        let tAttr: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 17, weight: .heavy), .foregroundColor: ink, .kern: 1.2]
        (title as NSString).draw(at: NSPoint(x: x, y: 11), withAttributes: tAttr)
        x += (title as NSString).size(withAttributes: tAttr).width + 12
        for (bit, sym) in [(0x01, "⌃"), (0x04, "⌥"), (0x02, "⇧"), (0x08, "⌘")] where (state.oneShot | state.oneShot >> 4) & UInt8(bit) != 0 {
            let r = NSRect(x: x, y: 10, width: 30, height: 24)
            orange.setFill(); NSBezierPath(roundedRect: r, xRadius: 8, yRadius: 8).fill()
            let a: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 15, weight: .bold), .foregroundColor: NSColor.white]
            let s = (sym as NSString).size(withAttributes: a)
            (sym as NSString).draw(at: NSPoint(x: r.midX - s.width / 2, y: r.midY - s.height / 2), withAttributes: a)
            x += 36
        }
        if state.oneShot != 0 && !showsMap {
            ("next key" as NSString).draw(at: NSPoint(x: x + 2, y: 15), withAttributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: muted])
        }
        guard showsMap, let ctx = NSGraphicsContext.current?.cgContext else { return }

        let lit = Set(Keymap.layerKey[state.layer] ?? [])
        for (i, (gx, gy)) in Keymap.geo.enumerated() {
            let cx = pad + ((Keymap.isRight(i) ? gx - pull : gx) * unit) + unit / 2
            let cy = header + gy * unit + unit / 2
            let label = Keymap.label(layer: state.layer, index: i)
            let own = Keymap.layers[state.layer][i]
            ctx.saveGState()
            ctx.translateBy(x: cx, y: cy)
            ctx.rotate(by: (Keymap.rotation[i] ?? 0) * .pi / 180)
            let r = NSRect(x: -cap / 2, y: -cap / 2, width: cap, height: cap)
            let path = NSBezierPath(roundedRect: r, xRadius: 6, yRadius: 6)
            if lit.contains(i) { accent.withAlphaComponent(0.35).setFill(); path.fill(); accent.setStroke(); path.lineWidth = 1.6 }
            else if own.isEmpty { ink.withAlphaComponent(0.04).setFill(); path.fill(); ink.withAlphaComponent(0.12).setStroke(); path.lineWidth = 0.8 }
            else { ink.withAlphaComponent(own == "·" ? 0.05 : 0.10).setFill(); path.fill(); ink.withAlphaComponent(0.22).setStroke(); path.lineWidth = 0.8 }
            path.stroke()
            if !label.isEmpty && !(own.isEmpty && state.layer != 0) {
                let size: CGFloat = label.count <= 1 ? 13 : label.count <= 3 ? 9.5 : 8
                let a: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: .semibold),
                                                        .foregroundColor: own == "·" ? muted.withAlphaComponent(0.6) : ink]
                let s = (label as NSString).size(withAttributes: a)
                (label as NSString).draw(at: NSPoint(x: -s.width / 2, y: -s.height / 2), withAttributes: a)
            }
            ctx.restoreGState()
        }
    }
}
