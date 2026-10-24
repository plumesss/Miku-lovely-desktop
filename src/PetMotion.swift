import AppKit
import QuartzCore

// Existing artwork animated as local-deformation frames, not a Cubism model.
final class PetMotionClip {
    struct Frame {
        let image: NSImage
        let bitmap: NSBitmapImageRep
    }
    let frames: [Frame]
    static let padding: CGFloat = 0.06

    init?(skin: String, state: String) {
        guard let url = Bundle.main.url(forResource: skin + "_" + state,
                                        withExtension: "png", subdirectory: "animation"),
              let data = try? Data(contentsOf: url),
              let bitmap = NSBitmapImageRep(data: data), let atlas = bitmap.cgImage else { return nil }
        let width = atlas.width / 8, height = atlas.height / 6
        var loaded: [Frame] = []
        for i in 0..<48 {
            guard let cg = atlas.cropping(to: CGRect(x: (i % 8) * width, y: (i / 8) * height,
                                                    width: width, height: height)) else { return nil }
            loaded.append(Frame(image: NSImage(cgImage: cg, size: NSSize(width: width, height: height)),
                                bitmap: NSBitmapImageRep(cgImage: cg)))
        }
        frames = loaded
    }

    func frame(at time: TimeInterval) -> Frame {
        frames[Int(time.truncatingRemainder(dividingBy: 4) * 12) % frames.count]
    }

    static func padded(_ rect: CGRect) -> CGRect {
        let scale = padding / (1 - 2 * padding)
        return rect.insetBy(dx: -rect.width * scale, dy: -rect.height * scale)
    }
}

final class PetMotion {
    enum Gesture { case tap, feed, gift, arrival }
    private var clips: [String: PetMotionClip] = [:]
    private var order: [String] = []
    private let started = CACurrentMediaTime()
    private var gesture: Gesture?
    private var gestureStarted: TimeInterval = 0
    private(set) var gaze: CGFloat = 0
    var enabled = true
    var dragging = false
    var time: TimeInterval { CACurrentMediaTime() - started }

    func clip(skin: String, state: String) -> PetMotionClip? {
        guard enabled else { return nil }
        let key = skin + "_" + state
        if let existing = clips[key] { return existing }
        guard let loaded = PetMotionClip(skin: skin, state: state) else { return nil }
        // Bound decoded memory. Atlas assets are decompressed only when needed.
        while order.count >= 2 { clips.removeValue(forKey: order.removeFirst()) }
        clips[key] = loaded; order.append(key)
        return loaded
    }

    func clear() { clips.removeAll(); order.removeAll() }
    func play(_ action: Gesture) { gesture = action; gestureStarted = time }

    func tick(mouseX: CGFloat) {
        let target = max(-1, min(1, mouseX))
        gaze += (target - gaze) * 0.07
    }

    func transform(in rect: CGRect, sleeping: Bool) -> NSAffineTransform {
        let result = NSAffineTransform()
        guard enabled else { return result }
        let t = time
        let quiet: CGFloat = sleeping ? 0.25 : 1
        var angle = quiet * (0.7 * sin(t * 1.6) + gaze * 0.65)
        var bob = quiet * 0.7 * sin(t * 2.2)
        var scaleX: CGFloat = 1
        var scaleY: CGFloat = 1
        if dragging { angle += gaze * 5 }
        if let action = gesture {
            let elapsed = t - gestureStarted
            let duration: Double = action == .feed ? 2.2 : 1.6
            if elapsed < duration {
                let progress = elapsed / duration
                let envelope = CGFloat(sin(.pi * progress))
                switch action {
                case .tap, .gift, .arrival:
                    bob -= abs(sin(CGFloat(progress) * .pi * 3)) * 13 * envelope
                    angle += sin(CGFloat(progress) * .pi * 4) * 3 * envelope
                    scaleY += 0.035 * envelope * sin(CGFloat(progress) * .pi * 6)
                    scaleX -= 0.018 * envelope * sin(CGFloat(progress) * .pi * 6)
                case .feed:
                    angle += sin(CGFloat(progress) * .pi * 8) * 2.1 * envelope
                    bob -= abs(sin(CGFloat(progress) * .pi * 6)) * 4 * envelope
                    scaleY += 0.018 * envelope * sin(CGFloat(progress) * .pi * 10)
                }
            } else { gesture = nil }
        }
        result.translateX(by: rect.midX, yBy: rect.maxY + bob)
        result.rotate(byDegrees: angle)
        result.scaleX(by: scaleX, yBy: scaleY)
        result.translateX(by: -rect.midX, yBy: -rect.maxY)
        return result
    }
}
