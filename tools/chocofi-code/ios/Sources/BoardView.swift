import UIKit

// The in-app "HUD": the live layer map, armed one-shots and held modifiers, with the keys for
// the next character outlined in green.
final class BoardView: UIView {
    var state = KeyState() { didSet { if state != oldValue { setNeedsDisplay() } } }
    var target: [Int] = [] { didSet { if target != oldValue { setNeedsDisplay() } } }

    private let pull: CGFloat = 1.4, header: CGFloat = 40

    override init(frame: CGRect) { super.init(frame: frame); isOpaque = false; contentMode = .redraw }
    required init?(coder: NSCoder) { fatalError() }

    // board is 12-pull+1 units wide and 5.1 units tall below the header
    override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: 230) }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let ink = UIColor.label, muted = UIColor.secondaryLabel
        let accent = UIColor.tintColor, orange = UIColor.systemOrange, green = UIColor.systemGreen

        let unit = min((bounds.width - 32) / (13 - pull), (bounds.height - header - 8) / 5.1)
        let cap = unit * 0.87
        let boardW = (13 - pull) * unit
        let left = (bounds.width - boardW) / 2

        // header: layer name, one-shot pills, held modifiers, caps
        var x = left
        let title = Keymap.layerNames[min(state.layer, Keymap.layerNames.count - 1)]
        let tAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 17, weight: .heavy),
                                                    .foregroundColor: state.layer == 0 ? muted : ink, .kern: 1.2]
        (title as NSString).draw(at: CGPoint(x: x, y: 10), withAttributes: tAttr)
        x += (title as NSString).size(withAttributes: tAttr).width + 12
        let order: [(UInt8, String)] = [(0x01, "⌃"), (0x04, "⌥"), (0x02, "⇧"), (0x08, "⌘")]
        for (bit, sym) in order where state.oneShot & bit != 0 || state.held & bit != 0 {
            let armed = state.oneShot & bit != 0
            let r = CGRect(x: x, y: 8, width: 30, height: 26)
            let p = UIBezierPath(roundedRect: r, cornerRadius: 8)
            if armed { orange.setFill(); p.fill() } else { ink.withAlphaComponent(0.12).setFill(); p.fill() }
            let a: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 15, weight: .bold),
                                                    .foregroundColor: armed ? UIColor.white : ink]
            let s = (sym as NSString).size(withAttributes: a)
            (sym as NSString).draw(at: CGPoint(x: r.midX - s.width / 2, y: r.midY - s.height / 2), withAttributes: a)
            x += 36
        }
        if state.oneShot != 0 {
            ("one-shot: applies to the next key" as NSString).draw(at: CGPoint(x: x + 2, y: 14), withAttributes:
                [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: muted])
        }
        var right = state.caps ? "CAPS LOCK" : ""
        if !state.signalled { right = "No layer signals yet · reflash, or ADJUST + I" }
        if !right.isEmpty {
            let a: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12, weight: .medium),
                                                    .foregroundColor: state.caps ? orange : muted]
            let s = (right as NSString).size(withAttributes: a)
            (right as NSString).draw(at: CGPoint(x: left + boardW - s.width, y: 14), withAttributes: a)
        }

        let lit = Set(Keymap.layerKey[state.layer] ?? [])
        let next = Set(target)
        for (i, (gx, gy)) in Keymap.geo.enumerated() {
            let cx = left + ((Keymap.isRight(i) ? gx - pull : gx) * unit) + unit / 2
            let cy = header + gy * unit + unit / 2
            let label = Keymap.label(layer: state.layer, index: i)
            let own = Keymap.layers[state.layer][i]
            ctx.saveGState()
            ctx.translateBy(x: cx, y: cy)
            ctx.rotate(by: (Keymap.rotation[i] ?? 0) * .pi / 180)
            let r = CGRect(x: -cap / 2, y: -cap / 2, width: cap, height: cap)
            let path = UIBezierPath(roundedRect: r, cornerRadius: cap * 0.22)
            path.lineWidth = 0.8
            if lit.contains(i) { accent.withAlphaComponent(0.35).setFill(); path.fill(); accent.setStroke(); path.lineWidth = 1.6 }
            else if own.isEmpty { ink.withAlphaComponent(0.04).setFill(); path.fill(); ink.withAlphaComponent(0.12).setStroke() }
            else { ink.withAlphaComponent(own == "·" ? 0.05 : 0.10).setFill(); path.fill(); ink.withAlphaComponent(0.22).setStroke() }
            path.stroke()
            if next.contains(i) {
                let ring = UIBezierPath(roundedRect: r.insetBy(dx: -2.5, dy: -2.5), cornerRadius: cap * 0.26)
                ring.lineWidth = 2.5; green.setStroke(); ring.stroke()
            }
            if !label.isEmpty && !(own.isEmpty && state.layer != 0) {
                let k = cap / 26
                let size: CGFloat = (label.count <= 1 ? 13 : label.count <= 3 ? 9.5 : 8) * k
                let a: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: size, weight: .semibold),
                                                        .foregroundColor: own == "·" ? muted.withAlphaComponent(0.6) : ink]
                let s = (label as NSString).size(withAttributes: a)
                (label as NSString).draw(at: CGPoint(x: -s.width / 2, y: -s.height / 2), withAttributes: a)
            }
            ctx.restoreGState()
        }
    }
}
