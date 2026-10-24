import AppKit

// Texture-based lip rig for existing PNG art; not a Cubism model.
final class PetMouthRig {
    private struct Entry: Decodable { let rect: [Double] }
    private let manifest: [String: Entry]
    private var cache: [String: [NSImage]] = [:]
    init() {
        if let url = Bundle.main.url(forResource: "manifest", withExtension: "json", subdirectory: "mouths"),
           let data = try? Data(contentsOf: url),
           let loaded = try? JSONDecoder().decode([String: Entry].self, from: data) { manifest = loaded }
        else { manifest = [:] }
    }
    func draw(skin: String, state: String, in rect: CGRect, time: Double?, amount: CGFloat) {
        let key = skin + "_" + state
        guard let entry = manifest[key], entry.rect.count == 4 else { return }
        if cache[key] == nil {
            let images = (0..<5).compactMap { level -> NSImage? in
                guard let url = Bundle.main.url(forResource: key + "_\(level)", withExtension: "png", subdirectory: "mouths") else { return nil }
                return NSImage(contentsOf: url)
            }
            guard images.count == 5 else { return }
            if cache.count >= 3 { cache.removeAll() }
            cache[key] = images
        }
        guard let images = cache[key] else { return }
        let n = entry.rect
        let mouth = CGRect(x: rect.minX + n[0] * rect.width, y: rect.minY + n[1] * rect.height,
                           width: n[2] * rect.width, height: n[3] * rect.height)
        NSGraphicsContext.saveGraphicsState()
        if let time {
            let phase = Double(Int(time.truncatingRemainder(dividingBy: 4) * 12)) * 2 * .pi / 48
            func mapped(_ p: CGPoint) -> CGPoint {
                let ix = (p.x - rect.minX) / rect.width, iy = (p.y - rect.minY) / rect.height
                var x = ix, y = iy
                let dims: (Double, Double, Double) = skin == "standard" ? (0.15, 0.17, 0.16) : skin == "chibi" ? (0.25, 0.29, 0.28) : (0.34, 0.29, 0.29)
                let quiet = state == "sleep" ? 0.42 : 1.0
                // Invert the frame generator's inverse sampling field.
                for _ in 0..<4 {
                    let xx = x - 0.5
                    let head = exp(-pow((y - dims.0) / dims.1, 4) - pow(xx / dims.2, 4))
                    let hair = max(0, min(1, (abs(xx) - dims.2 * 0.7) / 0.18)) * max(0, min(1, (y - dims.0) / 0.55))
                    let dx = quiet * (0.004 * sin(phase) * (1 - y) + head * 0.010 * sin(phase) + hair * 0.026 * sin(phase + y * 3 + (xx < 0 ? -0.8 : 0.8)))
                    var dy = quiet * (-0.005 * sin(phase * 2) * (1 - y) + head * 0.005 * cos(phase))
                    if skin == "crayon" && state != "sleep" { dy += head * 0.006 * (cos(phase * 3) - 0.3) }
                    x = ix + dx; y = iy + dy
                }
                return CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
            }
            let c = CGPoint(x: mouth.midX, y: mouth.midY), p = mapped(c)
            let dx = mapped(CGPoint(x: c.x + 0.1, y: c.y)), dy = mapped(CGPoint(x: c.x, y: c.y + 0.1))
            let a = (dx.x - p.x) * 10, b = (dx.y - p.y) * 10
            let cc = (dy.x - p.x) * 10, d = (dy.y - p.y) * 10
            let t = NSAffineTransform()
            t.transformStruct = NSAffineTransformStruct(m11: a, m12: b, m21: cc, m22: d,
                                                        tX: p.x - a * c.x - cc * c.y, tY: p.y - b * c.x - d * c.y)
            t.concat()
        }
        let value = min(4, max(0, amount * 4)), low = Int(floor(value)), high = min(4, low + 1)
        images[low].draw(in: mouth, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high.rawValue])
        if high != low && value > CGFloat(low) {
            images[high].draw(in: mouth, from: .zero, operation: .sourceOver,
                              fraction: value - CGFloat(low), respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high.rawValue])
        }
        NSGraphicsContext.restoreGraphicsState()
    }
}
