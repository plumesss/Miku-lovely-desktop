// MikuDeskPet — macOS 桌面宠物：初音未来
// 透明悬浮窗 · 拖拽 · 点击互动 · 心情系统 · 整点问候 · 设置面板 · 开机自启

import AppKit
import AVFoundation
@preconcurrency import CoreLocation
import QuartzCore

// MARK: - 常量

let kBundleID = "com.miku.deskpet"
let kSkin = "skin"
let kSize = "petSize"
let kOpacity = "petOpacity"
let kHourly = "hourlyGreeting"
let kLaunchAtLogin = "launchAtLogin"
let kMood = "mood"
let kHasRun = "hasRun"
let kSoundOn = "soundOn"
let kSoundVolume = "soundVolume"
let kMotionOn = "motionOn"

let defaults = UserDefaults.standard

enum WeatherEffect: Equatable {
    case none
    case snow
    case rain
    case sun
    case stars
    case cherry
    case maple
}

// MARK: - 台词库

struct Lines {
    static let launch = [
        "你好呀～我是初音未来，今天开始住进你的桌面啦🎵",
        "叮咚～未来酱上线！今天也请多指教哦♪",
        "报道！元气满满的初音未来，来陪你啦✨",
    ]
    static let hourly: [Int: String] = [
        6: "清晨6点，早起的你超棒的！",
        7: "早上好！记得吃早饭哦～",
        8: "新的一天开始啦，今天也加油！",
        10: "上午好呀～休息一下眼睛吧👀",
        12: "中午啦！记得吃午饭，要好好吃饭哦🍚",
        14: "下午茶时间～要不要起来走一走？",
        16: "下午四点，来杯水吧～",
        18: "傍晚啦，辛苦一天咯！",
        20: "晚上好呀～今晚想听什么歌？",
        22: "夜深咯，早点休息哦～",
        0: "零点了…未来酱也要睡了…Zzz",
    ]
    static let tapNormal = [
        "诶嘿嘿～被戳到了啦(〃∀〃)",
        "干嘛呀～痒痒的！",
        "想听我唱歌嘛？♫",
        "摸摸头，会变聪明的哦！",
        "大葱大葱～♪",
        "一直在哦，随时找我玩～",
    ]
    static let tapHappy = [
        "最喜欢你啦！♡",
        "今天心情超好，给你唱首歌吧～♪",
        "嘿嘿，再戳我也不怕痒！",
        "和你在一起，每天都好开心✨",
    ]
    static let tapSad = [
        "呜…你好久没陪我了啦(´；ω；`)",
        "有点孤单呢…多陪陪我好不好？",
        "戳戳也开心…一点点啦。",
    ]
    static let sleepTalk = [
        "嗯…还早啦…再睡会儿…Zzz",
        "呜…被发现了…晚安…",
        "呼…呼…（说梦话中）♪",
    ]
    static let feed = [
        "哇！大葱！未来酱的最爱！！♪",
        "大葱！谢谢款待，人间美味～🎵",
        "咔嚓咔嚓…幸福～谢谢你！",
    ]
    static let drag = [
        "哇，飞起来啦～",
        "哇啊！轻一点啦(⊙ω⊙)",
        "空中散步中～♪",
    ]
    static let chatter = [
        "♫ 啦啦啦～♪（哼歌中）",
        "工作累了就休息一下眼睛吧～",
        "桌面前好干净呀，继续保持哦！",
        "喵？有什么想让我做的嘛？",
        "♫～♫～（练习新歌中）",
    ]
    static let chatterSad = [
        "……（未来酱看起来有点没精神）",
        "呜…陪陪我嘛…",
    ]
}

// MARK: - 可选本地语音（公开构建不包含语音资源）

final class SoundManager: NSObject, AVAudioPlayerDelegate {
    static let shared = SoundManager()
    private var cache: [String: AVAudioPlayer] = [:]
    private(set) var activePlayer: AVAudioPlayer?
    private(set) var mouthAmount: CGFloat = 0
    var isSpeaking: Bool { enabled && volume > 0 && activePlayer?.isPlaying == true }
    func stop() {
        activePlayer?.stop()
        activePlayer = nil
        mouthAmount = 0
    }
    // Sample actual voice audio at 30 Hz, independently of text bubbles.
    func updateMouth() {
        guard enabled, volume > 0 else { stop(); return }
        guard let player = activePlayer, player.isPlaying else { mouthAmount = 0; return }
        player.volume = volume
        player.updateMeters()
        let db = player.averagePower(forChannel: 0)
        let target: CGFloat = db < -44 ? 0 : CGFloat(min(1, max(0, (db + 44) / 32)))
        mouthAmount += (target - mouthAmount) * (target > mouthAmount ? 0.72 : 0.55)
        if mouthAmount < 0.015 { mouthAmount = 0 }
    }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if player === activePlayer { stop() }
    }
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if player === activePlayer { stop() }
    }

    var available: Bool { Bundle.main.url(forResource: "voice_01", withExtension: "m4a", subdirectory: "sounds") != nil }
    var enabled: Bool { available && (defaults.object(forKey: kSoundOn) == nil || defaults.bool(forKey: kSoundOn)) }
    var volume: Float { defaults.object(forKey: kSoundVolume) == nil ? 0.8 : defaults.float(forKey: kSoundVolume) }

    func play(_ name: String) {
        stop()
        guard enabled, volume > 0 else { return }
        let player: AVAudioPlayer
        if let p = cache[name] {
            player = p
        } else {
            // The build script installs the downloaded files under the stable
            // voice_01...voice_10 names. Keep the original asset name as a
            // fallback so older bundles still play after an in-place update.
            let number = name.split(separator: "_").last.map(String.init) ?? name
            let candidates = [name, "voice_selfep_piapro_21_" + number]
            guard let url = candidates.compactMap({ Bundle.main.url(forResource: $0, withExtension: "m4a", subdirectory: "sounds") }).first else {
                NSLog("[miku] audio resource missing: %@", name)
                return
            }
            guard let p = try? AVAudioPlayer(contentsOf: url) else {
                NSLog("[miku] audio resource could not be opened: %@", url.path)
                return
            }
            p.prepareToPlay()
            cache[name] = p
            player = p
        }
        player.delegate = self
        player.isMeteringEnabled = true
        player.volume = volume
        player.currentTime = 0
        activePlayer = player
        if !player.play() {
            NSLog("[miku] audio play failed: %@", name)
            stop()
        }
    }

    func playRandom(_ names: [String]) {
        if let n = names.randomElement() { play(n) }
    }
}

// MARK: - 皮肤（形象）资源

final class SkinSet {
    let name: String
    let idle: NSImage
    let blink: NSImage
    let happy: NSImage
    let sad: NSImage
    let sleep: NSImage
    private(set) var reps: [NSBitmapImageRep] = []

    init?(name: String) {
        func load(_ f: String) -> NSImage? {
            NSImage(named: NSImage.Name(f))
        }
        guard let a = load(name + "_idle"), let b = load(name + "_blink"),
              let c = load(name + "_happy"), let d = load(name + "_sad"),
              let e = load(name + "_sleep") else { return nil }
        self.name = name
        idle = a; blink = b; happy = c; sad = d; sleep = e
        for img in [a, b, c, d, e] {
            var rect = CGRect(origin: .zero, size: img.size)
            if let cg = img.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
                reps.append(NSBitmapImageRep(cgImage: cg))
            }
        }
    }

    func rep(for img: NSImage) -> NSBitmapImageRep? {
        let idx: Int
        if img === idle { idx = 0 } else if img === blink { idx = 1 }
        else if img === happy { idx = 2 } else if img === sad { idx = 3 } else { idx = 4 }
        return reps.indices.contains(idx) ? reps[idx] : nil
    }
}

// MARK: - 立绘视图（绘制 + 鼠标交互 + 呼吸动画）

final class FigureView: NSView {
    var skin: SkinSet?
    var current: NSImage?
    let motion = PetMotion()
    let mouthRig = PetMouthRig()
    private var renderedMouthAmount: CGFloat = -1
    private var renderedSpeechActive = false
    private var motionTimer: Timer?
    private var renderedFrame: PetMotionClip.Frame?
    private var renderedRect = CGRect.zero
    private var renderedTransform = NSAffineTransform()

    private var currentState: String {
        guard let skin, let current else { return "idle" }
        if current === skin.blink { return "blink" }
        if current === skin.happy { return "happy" }
        if current === skin.sad { return "sad" }
        if current === skin.sleep { return "sleep" }
        return "idle"
    }
    var petHeight: CGFloat = 260 { didSet { needsDisplay = true; addBreathing() } }
    var weatherEffect: WeatherEffect = .none { didSet { needsDisplay = true } }
    var weatherPhase: CGFloat = 0 { didSet { if weatherEffect != .none { needsDisplay = true } } }
    var onTap: (() -> Void)?
    var onFeedRequest: (() -> Void)?
    var onMenuRequest: ((NSPoint) -> Void)?
    override var isFlipped: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    func figureRect() -> CGRect {
        guard let img = current else { return .zero }
        let aspect = img.size.width / img.size.height
        let w = petHeight * aspect
        let x = (bounds.width - w) / 2
        return CGRect(x: x, y: bounds.height - petHeight - 2, width: w, height: petHeight)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let img = current else { return }
        let r = figureRect()
        let frameTime = motion.time
        let transform = motion.transform(in: r, sleeping: currentState == "sleep")
        renderedTransform = transform.copy() as! NSAffineTransform
        NSGraphicsContext.saveGraphicsState()
        transform.concat()
        if let skin, let clip = motion.clip(skin: skin.name, state: currentState) {
            let frame = clip.frame(at: frameTime)
            let padded = PetMotionClip.padded(r)
            frame.image.draw(in: padded, from: .zero, operation: .sourceOver,
                             fraction: 1, respectFlipped: true,
                             hints: [.interpolation: NSImageInterpolation.high.rawValue])
            renderedFrame = frame
            renderedRect = padded
        } else {
            img.draw(in: r, from: .zero, operation: .sourceOver,
                     fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high.rawValue])
            renderedFrame = nil
            renderedRect = r
        }
        // Preserve the original expression's mouth whenever no voice is playing.
        let speechActive = SoundManager.shared.isSpeaking
        if speechActive, let skin {
            mouthRig.draw(skin: skin.name, state: currentState, in: r,
                          time: renderedFrame == nil ? nil : frameTime,
                          amount: SoundManager.shared.mouthAmount)
        }
        renderedSpeechActive = speechActive
        renderedMouthAmount = SoundManager.shared.mouthAmount
        NSGraphicsContext.restoreGraphicsState()
        drawWeatherEffect(in: r)
    }

    private func drawWeatherEffect(in rect: CGRect) {
        guard weatherEffect != .none else { return }
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: rect).addClip()
        func drawFallingParticle(_ i: Int, color: NSColor, leaf: Bool = false) {
            let xRatio = CGFloat((i * 47 + 13) % 100) / 100
            let speed = 0.42 + CGFloat(i % 5) * 0.07
            let yRatio = (CGFloat((i * 31) % 100) / 100 + weatherPhase * speed).truncatingRemainder(dividingBy: 1)
            let x = rect.minX + rect.width * xRatio
            let y = rect.minY + rect.height * yRatio
            let size = CGFloat(2.0 + Double(i % 3) * 0.8)
            color.withAlphaComponent(0.82).setFill()
            let path = NSBezierPath()
            if leaf {
                path.move(to: NSPoint(x: x, y: y - size * 1.6))
                path.line(to: NSPoint(x: x + size * 1.5, y: y - size * 0.35))
                path.line(to: NSPoint(x: x + size * 0.7, y: y + size * 1.4))
                path.line(to: NSPoint(x: x - size * 0.8, y: y + size * 1.1))
                path.line(to: NSPoint(x: x - size * 1.4, y: y - size * 0.3))
            } else {
                path.move(to: NSPoint(x: x, y: y - size * 1.5))
                path.curve(to: NSPoint(x: x + size * 1.5, y: y), controlPoint1: NSPoint(x: x + size * 1.2, y: y - size * 1.5), controlPoint2: NSPoint(x: x + size * 1.5, y: y - size * 0.6))
                path.curve(to: NSPoint(x: x, y: y + size * 1.5), controlPoint1: NSPoint(x: x + size * 1.5, y: y + size * 0.6), controlPoint2: NSPoint(x: x + size * 0.8, y: y + size * 1.5))
                path.curve(to: NSPoint(x: x - size * 1.5, y: y), controlPoint1: NSPoint(x: x - size * 0.8, y: y + size * 1.5), controlPoint2: NSPoint(x: x - size * 1.5, y: y + size * 0.6))
                path.curve(to: NSPoint(x: x, y: y - size * 1.5), controlPoint1: NSPoint(x: x - size * 1.5, y: y - size * 0.6), controlPoint2: NSPoint(x: x - size * 1.2, y: y - size * 1.5))
            }
            path.close()
            path.fill()
        }
        func drawCherryPetal(_ i: Int) {
            let xRatio = CGFloat((i * 47 + 13) % 100) / 100
            let speed = 0.50 + CGFloat(i % 5) * 0.08
            let yRatio = (CGFloat((i * 31) % 100) / 100 + weatherPhase * speed).truncatingRemainder(dividingBy: 1)
            let x = rect.minX + rect.width * xRatio
            let y = rect.minY + rect.height * yRatio
            let width = CGFloat(3.4 + Double(i % 3) * 1.1)
            let height = width * 0.58
            let angle = weatherPhase * (0.9 + CGFloat(i % 4) * 0.12) + CGFloat(i) * 0.9
            let dx = cos(angle) * width * 0.45
            let dy = sin(angle) * width * 0.45
            let petal = NSBezierPath()
            petal.move(to: NSPoint(x: x - dx, y: y - dy))
            petal.curve(to: NSPoint(x: x + dx, y: y + dy),
                        controlPoint1: NSPoint(x: x + cos(angle + .pi / 2) * height, y: y + sin(angle + .pi / 2) * height),
                        controlPoint2: NSPoint(x: x + cos(angle + .pi / 2) * height, y: y + sin(angle + .pi / 2) * height))
            petal.curve(to: NSPoint(x: x - dx, y: y - dy),
                        controlPoint1: NSPoint(x: x + cos(angle - .pi / 2) * height, y: y + sin(angle - .pi / 2) * height),
                        controlPoint2: NSPoint(x: x + cos(angle - .pi / 2) * height, y: y + sin(angle - .pi / 2) * height))
            petal.close()
            NSColor(calibratedRed: 1.0, green: 0.74, blue: 0.84, alpha: 0.86).setFill()
            petal.fill()
        }
        switch weatherEffect {
        case .snow:
            for i in 0..<22 {
                let xRatio = CGFloat((i * 47 + 13) % 100) / 100
                let speed = 0.55 + CGFloat(i % 5) * 0.08
                let yRatio = (CGFloat((i * 31) % 100) / 100 + weatherPhase * speed).truncatingRemainder(dividingBy: 1)
                let x = rect.minX + rect.width * xRatio
                let y = rect.minY + rect.height * yRatio
                let radius = CGFloat(1.2 + Double(i % 3) * 0.7)
                NSColor.white.withAlphaComponent(0.78).setFill()
                NSBezierPath(ovalIn: NSRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)).fill()
            }
        case .rain:
            for i in 0..<30 {
                let xRatio = CGFloat((i * 37 + 9) % 100) / 100
                let speed = 0.9 + CGFloat(i % 4) * 0.08
                let yRatio = (CGFloat((i * 29) % 100) / 100 + weatherPhase * speed).truncatingRemainder(dividingBy: 1)
                let x = rect.minX + rect.width * xRatio
                let y = rect.minY + rect.height * yRatio
                let length = CGFloat(7 + i % 5)
                let streak = NSBezierPath()
                streak.move(to: NSPoint(x: x, y: y))
                streak.line(to: NSPoint(x: x - 2.5, y: y + length))
                streak.lineWidth = 1.2
                NSColor.systemBlue.withAlphaComponent(0.42).setStroke()
                streak.stroke()
            }
        case .sun:
            let center = NSPoint(x: rect.midX, y: rect.minY + rect.height * 0.18)
            let scale = CGFloat(min(rect.width, rect.height))
            let halos: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (0.25, 0.00, 0.16, 0.16), (0.16, -0.20, 0.11, 0.13),
                (0.13, 0.22, 0.10, 0.14), (0.09, -0.30, 0.19, 0.10),
                (0.08, 0.34, 0.20, 0.09), (0.05, -0.08, 0.31, 0.18),
                (0.04, 0.28, 0.38, 0.12), (0.03, -0.36, 0.43, 0.10)
            ]
            for (i, halo) in halos.enumerated() {
                let pulse = 1.0 + 0.08 * sin(weatherPhase * 1.8 + CGFloat(i))
                let radius = scale * halo.0 * pulse
                let drift = weatherPhase * (0.7 + CGFloat(i) * 0.04) + CGFloat(i)
                let x = center.x + rect.width * (halo.1 + sin(drift) * 0.025)
                let y = center.y + rect.height * (halo.2 + cos(drift * 0.8) * 0.018)
                NSColor.systemYellow.withAlphaComponent(halo.3).setFill()
                NSBezierPath(ovalIn: NSRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)).fill()
            }
        case .stars:
            for i in 0..<12 {
                let travel = (weatherPhase * (0.40 + CGFloat(i % 4) * 0.08) + CGFloat(i) * 0.19).truncatingRemainder(dividingBy: 1)
                let x = rect.minX + rect.width * (0.08 + CGFloat((i * 67) % 84) / 100 + travel * 0.20)
                let y = rect.minY + rect.height * (0.12 + CGFloat((i * 31) % 72) / 100 + travel * 0.45)
                let length = CGFloat(10 + i % 5 * 3)
                let streak = NSBezierPath()
                streak.move(to: NSPoint(x: x, y: y))
                streak.line(to: NSPoint(x: x - length * 0.72, y: y - length))
                streak.lineWidth = CGFloat(1.2 + Double(i % 2) * 0.7)
                NSColor.white.withAlphaComponent(0.42 + 0.04 * CGFloat(i % 4)).setStroke()
                streak.stroke()
                let head = CGFloat(1.2 + Double(i % 2) * 0.7)
                NSColor.white.withAlphaComponent(0.88).setFill()
                NSBezierPath(ovalIn: NSRect(x: x - head, y: y - head, width: head * 2, height: head * 2)).fill()
            }
        case .cherry:
            for i in 0..<22 { drawCherryPetal(i) }
        case .maple:
            for i in 0..<18 { drawFallingParticle(i, color: i % 2 == 0 ? NSColor.systemRed : NSColor.systemOrange, leaf: true) }
        case .none:
            break
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    // 命中测试：只有画到不透明像素的位置才算点到了桌宠
    func isOpaquePoint(_ point: NSPoint) -> Bool {
        guard let skin = skin, let img = current, let rep = skin.rep(for: img) else { return false }
        let inverse = renderedTransform.copy() as! NSAffineTransform
        inverse.invert()
        let point = inverse.transform(point)
        if let frame = renderedFrame {
            let r = renderedRect
            guard r.width > 0, r.height > 0, r.contains(point) else { return false }
            let px = min(frame.bitmap.pixelsWide - 1, max(0, Int((point.x - r.minX) / r.width * CGFloat(frame.bitmap.pixelsWide))))
            let py = min(frame.bitmap.pixelsHigh - 1, max(0, Int((point.y - r.minY) / r.height * CGFloat(frame.bitmap.pixelsHigh))))
            return (frame.bitmap.colorAt(x: px, y: py)?.alphaComponent ?? 0) > 0.16
        }
        let r = figureRect()
        guard r.contains(point) else { return false }
        let px = min(rep.pixelsWide - 1, max(0, Int((point.x - r.minX) / r.width * CGFloat(rep.pixelsWide))))
        let py = min(rep.pixelsHigh - 1, max(0, Int((point.y - r.minY) / r.height * CGFloat(rep.pixelsHigh))))
        // alphaComponent 为归一化值 0…1，阈值取 0.16（≈ 40/255）
        return (rep.colorAt(x: px, y: py)?.alphaComponent ?? 0) > 0.16
    }

    // 事件全部由 PetWindow.sendEvent 自主路由，此实现仅供 AppKit 内部查询
    override func hitTest(_ point: NSPoint) -> NSView? {
        isOpaquePoint(point) ? self : nil
    }

    // 鼠标事件由 PetWindow.sendEvent 统一路由后调这里
    func simulateTap() { onTap?() }
    func openContextMenu(at pt: NSPoint) { onMenuRequest?(pt) }

    // One clock for the character only; weather and speech bubbles stay independent.
    func addBreathing() {
        layer?.removeAnimation(forKey: "breath")
        motion.enabled = defaults.object(forKey: kMotionOn) == nil || defaults.bool(forKey: kMotionOn)
        guard motionTimer == nil else { return }
        motionTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            let sound = SoundManager.shared
            sound.updateMouth()
            guard let window = self.window, window.isVisible else { return }
            guard self.motion.enabled || sound.isSpeaking || self.renderedSpeechActive != sound.isSpeaking || self.renderedMouthAmount != sound.mouthAmount else { return }
            let mouse = self.convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
            self.motion.tick(mouseX: (mouse.x - self.bounds.midX) / max(self.bounds.width, 1))
            self.needsDisplay = true
        }
    }

    func setMotionEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: kMotionOn)
        motion.enabled = enabled
        if !enabled { motion.clear() }
        needsDisplay = true
    }

}

// MARK: - 气泡视图

final class BubbleView: NSView {
    private var text: String = ""
    var onHide: (() -> Void)?

    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil } // 气泡不拦截鼠标

    func show(_ s: String, in parent: NSView) {
        text = s
        let font = NSFont(name: "PingFangSC-Semibold", size: 13) ?? NSFont.systemFont(ofSize: 13, weight: .semibold)
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        para.lineSpacing = 3
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(red: 0.18, green: 0.22, blue: 0.28, alpha: 1), .paragraphStyle: para]
        let attributed = NSAttributedString(string: text, attributes: attrs)
        let maxTextWidth: CGFloat = 250
        let bounds = attributed.boundingRect(with: CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
                                             options: [.usesLineFragmentOrigin, .usesFontLeading])
        let tw = ceil(bounds.width) + 30
        let th = ceil(bounds.height) + 20
        self.frame = NSRect(x: (parent.bounds.width - tw) / 2, y: 10, width: tw, height: th)
        if self.superview == nil { parent.addSubview(self) }
        alphaValue = 0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            self.animator().alphaValue = 1
        }
        needsDisplay = true
    }

    func dismiss() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            self.animator().alphaValue = 0
        }, completionHandler: { self.removeFromSuperview() })
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !text.isEmpty else { return }
        let bubble = NSBezierPath(roundedRect: NSRect(x: 2, y: 0, width: bounds.width - 4, height: bounds.height - 10),
                                  xRadius: 14, yRadius: 14)
        // 尾巴
        let tail = NSBezierPath()
        let cx = bounds.midX
        tail.move(to: NSPoint(x: cx - 9, y: bounds.height - 11))
        tail.line(to: NSPoint(x: cx + 9, y: bounds.height - 11))
        tail.line(to: NSPoint(x: cx, y: bounds.height - 1))
        tail.close()
        bubble.append(tail)

        NSColor.white.withAlphaComponent(0.94).setFill()
        bubble.fill()
        NSColor(calibratedRed: 0.3, green: 0.78, blue: 0.82, alpha: 1).setStroke()
        bubble.lineWidth = 1.6
        bubble.stroke()

        let font = NSFont(name: "PingFangSC-Semibold", size: 13) ?? NSFont.systemFont(ofSize: 13, weight: .semibold)
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        para.lineSpacing = 3
        (text as NSString).draw(
            with: NSRect(x: 15, y: 6, width: bounds.width - 30, height: bounds.height - 20),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .foregroundColor: NSColor(red: 0.18, green: 0.22, blue: 0.28, alpha: 1), .paragraphStyle: para])
    }
}

// MARK: - 主窗口（非激活面板：点击不抢焦点；接管 sendEvent 自行路由鼠标）

final class PetWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    private var downGlobal = NSPoint.zero
    private var downOrigin = NSPoint.zero
    private var dragging = false
    private var downOnFigure = false

    override func sendEvent(_ event: NSEvent) {
        let type = event.type
        if type == .leftMouseDown || type == .leftMouseDragged || type == .leftMouseUp || type == .rightMouseDown {
            routeMouse(event)
            return
        }
        super.sendEvent(event)
    }

    private func routeMouse(_ event: NSEvent) {
        guard let content = contentView else { return }
        let local = event.locationInWindow // borderless 窗口：内容区坐标 == 窗口坐标
        switch event.type {
        case .leftMouseDown:
            downGlobal = NSEvent.mouseLocation
            downOrigin = frame.origin
            dragging = false
            (content as? FigureView)?.motion.dragging = false
            downOnFigure = (content as? FigureView)?.isOpaquePoint(local) ?? false
        case .leftMouseDragged:
            guard downOnFigure else { return }
            let now = NSEvent.mouseLocation
            if !dragging && hypot(now.x - downGlobal.x, now.y - downGlobal.y) > 3 { dragging = true }
            if dragging {
                (content as? FigureView)?.motion.dragging = true
                setFrameOrigin(NSPoint(x: downOrigin.x + (now.x - downGlobal.x),
                                       y: downOrigin.y + (now.y - downGlobal.y)))
                FeaturePanelController.shared.petWindowMoved()
            }
        case .leftMouseUp:
            (content as? FigureView)?.motion.dragging = false
            guard downOnFigure else { return }
            let moved = hypot(NSEvent.mouseLocation.x - downGlobal.x, NSEvent.mouseLocation.y - downGlobal.y)
            if !dragging || moved > 90 { (content as? FigureView)?.simulateTap() }
        case .rightMouseDown:
            if content.hitTest(local) != nil {
                (content as? FigureView)?.openContextMenu(at: local)
            }
        default:
            super.sendEvent(event)
        }
    }
}

// MARK: - 天气插件

private struct OpenMeteoResponse: Decodable {
    struct Current: Decodable {
        let temperature_2m: Double
        let weather_code: Int
        let is_day: Int
    }
    let current: Current
}

@MainActor
final class WeatherController: NSObject, @preconcurrency CLLocationManagerDelegate {
    static let shared = WeatherController()
    private let locationManager = CLLocationManager()
    private weak var pet: PetController?
    private(set) var status = "天气：等待定位"
    private var isRequesting = false
    private var latestWeatherCode: Int?
    private var latestIsDay: Int?
    private var demoEffect: WeatherEffect?
    private var demoTimer: Timer?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func start(pet: PetController) {
        self.pet = pet
        request()
    }

    func request() {
        demoEffect = nil
        guard CLLocationManager.locationServicesEnabled() else {
            update("天气：系统定位未开启", effect: .none)
            return
        }
        isRequesting = true
        switch locationManager.authorizationStatus {
        case .authorized, .authorizedAlways, .authorizedWhenInUse:
            status = "天气：正在定位…"
            locationManager.requestLocation()
        case .notDetermined:
            status = "天气：等待定位权限…"
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            update("天气：请在系统设置允许定位", effect: .none)
        @unknown default:
            update("天气：定位状态未知", effect: .none)
        }
        FeaturePanelController.shared.weatherUpdated()
    }

    func demo(_ effect: WeatherEffect) {
        demoEffect = effect
        let text: String
        switch effect {
        case .snow: text = "天气演示：下雪"
        case .rain: text = "天气演示：下雨"
        case .sun: text = "天气演示：晴天"
        case .stars: text = "天气演示：流星雨"
        case .cherry: text = "季节演示：樱花"
        case .maple: text = "季节演示：枫叶"
        case .none: text = "天气演示：关闭特效"
        }
        update(text, effect: effect)
    }

    func demoSequence() {
        demoTimer?.invalidate()
        let effects: [WeatherEffect] = [.sun, .rain, .stars, .cherry, .maple, .snow]
        var index = 0
        func next() {
            guard index < effects.count else { return }
            demo(effects[index])
            index += 1
            if index >= effects.count {
                demoTimer = nil
            }
        }
        next()
        demoTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { timer.invalidate(); return }
                if index >= effects.count { timer.invalidate(); self.demoTimer = nil; return }
                next()
            }
        }
    }

    func refreshScene() {
        guard demoEffect == nil else { return }
        recalculateEffect()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorized || manager.authorizationStatus == .authorizedAlways {
            request()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else {
            update("天气：没有拿到位置", effect: .none)
            return
        }
        fetchWeather(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isRequesting = false
        update("天气：定位失败，请稍后重试", effect: .none)
    }

    private func fetchWeather(latitude: CLLocationDegrees, longitude: CLLocationDegrees) {
        let endpoint = String(format: "https://api.open-meteo.com/v1/forecast?latitude=%.6f&longitude=%.6f&current=temperature_2m,weather_code,is_day&timezone=auto", latitude, longitude)
        guard let url = URL(string: endpoint) else {
            update("天气：地址无效", effect: .none)
            return
        }
        Task { [weak self] in
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 15
                let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.1"
                request.setValue("MikuDeskPet/\(version)", forHTTPHeaderField: "User-Agent")
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                    NSLog("[miku] weather HTTP status: %d", code)
                    self?.applyFailure()
                    return
                }
                guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let current = root["current"] as? [String: Any],
                      let temperature = (current["temperature_2m"] as? NSNumber)?.doubleValue,
                      let code = (current["weather_code"] as? NSNumber)?.intValue,
                      let isDay = (current["is_day"] as? NSNumber)?.intValue else {
                    NSLog("[miku] weather response parse failed: %@", String(data: data, encoding: .utf8) ?? "<non-UTF8>")
                    self?.applyFailure()
                    return
                }
                self?.apply(.init(temperature_2m: temperature, weather_code: code, is_day: isDay))
            } catch {
                NSLog("[miku] weather request failed: %@", error.localizedDescription)
                self?.applyFailure()
            }
        }
    }

    private func apply(_ current: OpenMeteoResponse.Current) {
        isRequesting = false
        let code = current.weather_code
        let description: String
        latestWeatherCode = code
        latestIsDay = current.is_day
        switch code {
        case 71...77, 85...86:
            description = "下雪"
        case 0...2 where current.is_day == 1:
            description = code == 0 ? "晴" : "晴间多云"
        case 0...3:
            description = "多云"
        case 51...67, 80...82:
            description = "有雨"
        case 95...99:
            description = "雷雨"
        default:
            description = "天气平稳"
        }
        status = String(format: "天气：%@ %.1f℃", description, current.temperature_2m)
        recalculateEffect()
        FeaturePanelController.shared.weatherUpdated()
    }

    private func applyFailure() {
        isRequesting = false
        latestWeatherCode = nil
        latestIsDay = nil
        update("天气：网络获取失败", effect: .none)
    }

    private func recalculateEffect() {
        guard let code = latestWeatherCode, let isDay = latestIsDay else { return }
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let month = calendar.component(.month, from: Date())
        let effect: WeatherEffect
        if (71...77).contains(code) || (85...86).contains(code) {
            effect = .snow
        } else if (51...67).contains(code) || (80...82).contains(code) {
            effect = .rain
        } else if hour >= 20 || hour < 6 || isDay == 0 {
            effect = .stars
        } else if (3...5).contains(month) {
            effect = .cherry
        } else if (9...11).contains(month) {
            effect = .maple
        } else if (0...2).contains(code) && isDay == 1 {
            effect = .sun
        } else {
            effect = .none
        }
        pet?.applyWeather(effect)
    }

    private func update(_ text: String, effect: WeatherEffect) {
        status = text
        pet?.applyWeather(effect)
        FeaturePanelController.shared.weatherUpdated()
    }
}

// MARK: - 控制器

@MainActor
final class PetController: NSObject, NSWindowDelegate {
    var window: PetWindow!
    var figure = FigureView(frame: .zero)
    let bubble = BubbleView(frame: .zero)
    var skin: SkinSet?
    var moodTimer: Timer?
    var blinkTimer: Timer?
    var clockTimer: Timer?
    var chatterTimer: Timer?
    var weatherTimer: Timer?
    var expressionTask: DispatchWorkItem?
    var lastHour = -1
    var mood: Int {
        get { defaults.object(forKey: kMood) == nil ? 60 : defaults.integer(forKey: kMood) }
        set { defaults.set(max(0, min(100, newValue)), forKey: kMood) }
    }

    func start() {
        NSApp.setActivationPolicy(.accessory)
        loadSkin()
        rebuildWindow(firstTime: true)
        WeatherController.shared.start(pet: self)

        moodTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task { @MainActor in self.mood -= 1; self.refreshBaseImage() }
        }
        clockTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { _ in
            Task { @MainActor in self.checkClock() }
        }
        lastHour = Calendar.current.component(.hour, from: Date()) // 启动时不立即报时
        chatterTimer = Timer.scheduledTimer(withTimeInterval: .random(in: 260...520), repeats: true) { _ in
            Task { @MainActor in self.idleChatter() }
        }

        scheduleBlink()

        if defaults.bool(forKey: kHasRun) == false {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [self] in
                say(random: Lines.launch)
                SoundManager.shared.playRandom(["voice_01", "voice_02"]) // こんにちはー！/ 初音ミクです！
                defaults.set(true, forKey: kHasRun)
            }
        }
    }

    // 窗口
    func rebuildWindow(firstTime: Bool = false) {
        let size = CGFloat(defaults.object(forKey: kSize) == nil ? 280 : defaults.float(forKey: kSize))
        let opacity = defaults.object(forKey: kOpacity) == nil ? 1.0 : Double(defaults.float(forKey: kOpacity))
        let maxAspect: CGFloat = skin?.name == "standard" ? 0.72 : 1.05
        let w = size * maxAspect + 36
        let h = size * 1.45 + 30

        if window == nil {
            window = PetWindow(contentRect: NSRect(x: 0, y: 0, width: w, height: h),
                               styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.ignoresMouseEvents = false

            figure.wantsLayer = true
            figure.onTap = { [self] in handleTap() }
            figure.onMenuRequest = { [self] pt in showMenu(at: pt) }
            window.contentView = figure
            figure.frame = NSRect(origin: .zero, size: NSSize(width: w, height: h))
            figure.autoresizingMask = [.width, .height]
            figure.addSubview(bubble)
        }
        var frame = window.frame
        let oldBottom = frame.minY
        let oldCenter = frame.midX
        frame = NSRect(x: 0, y: 0, width: w, height: h)
        window.setContentSize(frame.size)
        window.setFrameOrigin(NSPoint(x: oldCenter - w / 2, y: oldBottom))
        figure.petHeight = size
        window.alphaValue = CGFloat(opacity)
        figure.addBreathing()
        refreshBaseImage()
        positionOnScreenIfFirst(firstTime)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func positionOnScreenIfFirst(_ first: Bool) {
        guard first, let screen = NSScreen.main else { return }
        let sf = screen.visibleFrame
        let wf = window.frame
        window.setFrameOrigin(NSPoint(x: sf.maxX - wf.width - 80, y: sf.minY + 60))
    }

    func loadSkin() {
        expressionTask?.cancel()
        expressionTask = nil
        let name = defaults.string(forKey: kSkin) ?? "crayon"
        skin = SkinSet(name: name) ?? SkinSet(name: "crayon")
        figure.skin = skin
        figure.motion.clear()
    }

    // MARK: 状态图像

    var isNight: Bool {
        let h = Calendar.current.component(.hour, from: Date())
        return h >= 0 && h < 7
    }

    func baseImage() -> NSImage? {
        guard let skin = skin else { return nil }
        if isNight { return skin.sleep }
        if mood < 30 { return skin.sad }
        if mood >= 75 { return skin.happy }
        return skin.idle
    }

    func refreshBaseImage() {
        guard expressionTask == nil else { return }
        figure.current = baseImage()
        figure.needsDisplay = true
    }

    func applyWeather(_ effect: WeatherEffect) {
        figure.weatherEffect = effect
        weatherTimer?.invalidate()
        weatherTimer = nil
        guard effect != .none else { return }
        weatherTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.figure.weatherPhase += 0.035
            }
        }
    }

    func showExpression(_ img: NSImage?, seconds: Double = 1.4) {
        guard let img = img else { return }
        expressionTask?.cancel()
        figure.current = img
        figure.needsDisplay = true
        let task = DispatchWorkItem { [self] in
            expressionTask = nil
            refreshBaseImage()
        }
        expressionTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: task)
    }

    func scheduleBlink() {
        blinkTimer?.invalidate()
        blinkTimer = Timer.scheduledTimer(withTimeInterval: .random(in: 2.6...6.5), repeats: false) { _ in
            Task { @MainActor in
                if let skin = self.skin, self.figure.current === skin.idle {
                    self.figure.current = skin.blink
                    self.figure.needsDisplay = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in
                        if self.figure.current === skin.blink { self.refreshBaseImage() }
                    }
                }
                self.scheduleBlink()
            }
        }
    }

    // MARK: 互动

    func handleTap() {
        figure.motion.play(.tap)
        mood += 4
        SoundManager.shared.playRandom(["voice_03", "voice_04", "voice_08", "voice_09"])
        if isNight {
            showExpression(skin?.happy, seconds: 1.2)
            say(random: Lines.sleepTalk)
        } else if mood >= 75 {
            showExpression(skin?.happy)
            say(random: Lines.tapHappy)
        } else if mood < 30 {
            showExpression(skin?.sad, seconds: 1.2)
            say(random: Lines.tapSad)
        } else {
            showExpression(skin?.happy)
            say(random: Lines.tapNormal)
        }
        refreshBaseImage()
    }

    func feed() {
        figure.motion.play(.feed)
        mood += 15
        showExpression(skin?.happy, seconds: 1.8)
        say(random: Lines.feed)
        SoundManager.shared.playRandom(["voice_08", "voice_09", "voice_03"])
        refreshBaseImage()
    }

    func giveGift() {
        figure.motion.play(.gift)
        mood += 8
        showExpression(skin?.happy, seconds: 1.5)
        say(random: ["礼物收到啦！我会好好珍惜的～", "给我的惊喜吗？谢谢你！", "哇，好开心！今天的心情满分～"])
        SoundManager.shared.play("voice_09")
        refreshBaseImage()
    }

    func idleChatter() {
        guard window.isVisible else { return }
        if isNight { return }
        say(random: mood < 30 ? Lines.chatterSad : Lines.chatter)
        chatterTimer?.fireDate = Date().addingTimeInterval(.random(in: 260...520))
    }

    func checkClock() {
        refreshNightState()
        WeatherController.shared.refreshScene()
        let now = Date()
        let cal = Calendar.current
        let h = cal.component(.hour, from: now)
        let m = cal.component(.minute, from: now)
        guard m == 0 && h != lastHour else { return }
        lastHour = h
        if defaults.object(forKey: kHourly) == nil || defaults.bool(forKey: kHourly) {
            if let line = Lines.hourly[h] {
                say(line)
                SoundManager.shared.playRandom(["voice_07", "voice_10"]) // 精一杯歌うね / ミュージックスタート！
            }
        }
    }

    func refreshNightState() {
        let before = figure.current
        refreshBaseImage()
        if isNight, before !== skin?.sleep, figure.current === skin?.sleep, mood >= 30 {
            say("夜深啦…未来酱先睡咯…晚安…Zzz", thenSleep: true)
        }
    }

    // MARK: 气泡

    var bubbleHideTask: DispatchWorkItem?

    func say(_ text: String, thenSleep: Bool = false) {
        bubble.show(text, in: figure)
        bubbleHideTask?.cancel()
        let task = DispatchWorkItem { [self] in bubble.dismiss() }
        bubbleHideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + .random(in: 2.6...(2.6 + Double(text.count) * 0.22)), execute: task)
    }

    func say(random pool: [String]) {
        say(pool.randomElement() ?? "")
    }

    // MARK: 右键菜单

    func showMenu(at pt: NSPoint) {
        let menu = NSMenu()
        let motionItem = NSMenuItem(title: "✨ 动态模式", action: #selector(toggleMotion), keyEquivalent: "")
        motionItem.target = self
        motionItem.state = figure.motion.enabled ? .on : .off
        menu.addItem(motionItem)
        if SoundManager.shared.available {
            menu.addItem(withTitle: "🎤 演示语音口型", action: #selector(demoSpeech), keyEquivalent: "").target = self
        }
        menu.addItem(withTitle: "▶️ 演示桌宠动作", action: #selector(demoMotion), keyEquivalent: "").target = self
        menu.addItem(withTitle: "🎭 切换形象（当前：\(skinNameLabel)）", action: #selector(cycleSkin), keyEquivalent: "").target = self
        menu.addItem(withTitle: "🥬 投喂大葱", action: #selector(feedAction), keyEquivalent: "").target = self
        menu.addItem(withTitle: "💬 聊聊天", action: #selector(chatAction), keyEquivalent: "").target = self
        menu.addItem(withTitle: "🧰 打开功能面板", action: #selector(openFeaturePanel), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "⚙️ 设置…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "ℹ️ 关于初音桌宠", action: #selector(aboutAction), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "🚪 退出", action: #selector(quitAction), keyEquivalent: "q").target = self
        menu.popUp(positioning: nil, at: NSPoint(x: pt.x, y: pt.y), in: figure)
    }

    @objc func demoSpeech() {
        if !SoundManager.shared.enabled || SoundManager.shared.volume <= 0 {
            say("请在设置里打开初音语音，并调高音量～")
            return
        }
        SoundManager.shared.play("voice_03")
        say("听我说话，嘴巴会跟着声音动哦～")
    }

    @objc func toggleMotion() { figure.setMotionEnabled(!figure.motion.enabled) }
    @objc func demoMotion() {
        figure.setMotionEnabled(true)
        figure.motion.play(.arrival)
        showExpression(skin?.happy, seconds: 1.6)
        say("先摇摇头、动动双马尾，再跳一跳～")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.figure.motion.play(.feed)
        }
    }
    @objc func feedAction() { feed() }

    private var skinNameLabel: String {
        ["crayon": "涂鸦喏葱", "chibi": "Q版", "standard": "标准"][defaults.string(forKey: kSkin) ?? "crayon"] ?? "涂鸦喏葱"
    }

    @objc func cycleSkin() {
        let order = ["crayon", "chibi", "standard"]
        let cur = defaults.string(forKey: kSkin) ?? "crayon"
        // Advance with wraparound; indexing index + 1 before applying %
        // crashes when the current skin is the last item (standard).
        let nextIndex = ((order.firstIndex(of: cur) ?? -1) + 1) % order.count
        let next = order[nextIndex]
        defaults.set(next, forKey: kSkin)
        loadSkin()
        rebuildWindow()
        refreshBaseImage()
        say(next == "crayon" ? "换上喏葱装啦，开吃开吃！🥬" : (next == "chibi" ? "变成Q版啦，可爱吗？(〃∀〃)" : "厚涂立绘登场，闪闪发光✨"))
        SoundManager.shared.play("voice_10") // ミュージックスタート！
    }
    @objc func chatAction() { say(random: mood < 30 ? Lines.chatterSad : Lines.chatter) }
    @objc func openFeaturePanel() { FeaturePanelController.shared.show(pet: self) }
    @objc func aboutAction() {
        NSApp.activate(ignoringOtherApps: true)
        SettingsController.shared.showAbout()
    }
    @objc func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        SettingsController.shared.show(pet: self)
    }
    @objc func quitAction() { NSApp.terminate(nil) }

    // 拖拽结束后互动（performDrag 会吞掉 mouseUp，这里不重复处理）
}

// MARK: - 独立功能面板

@MainActor
final class FeaturePanelController: NSObject {
    static let shared = FeaturePanelController()
    private var panel: NSPanel?
    private weak var pet: PetController?
    private weak var moodLabel: NSTextField?
    private weak var clockLabel: NSTextField?
    private weak var weatherLabel: NSTextField?
    private weak var restButton: NSButton?
    private var clockTimer: Timer?
    private var restTimer: Timer?
    private var lastPanelOrigin = NSPoint.zero
    private var syncingWindows = false

    func show(pet: PetController) {
        self.pet = pet
        if panel == nil { build() }
        reposition()
        updateLabels()
        panel?.orderFrontRegardless()
    }

    private func build() {
        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 286, height: 520),
                        styleMask: [.titled, .closable, .utilityWindow],
                        backing: .buffered, defer: false)
        p.title = "初音功能"
        p.isReleasedWhenClosed = false
        p.hidesOnDeactivate = false
        p.level = .floating
        p.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 286, height: 520))
        panel = p
        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: p, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.panelWindowMoved() }
        }

        guard let c = p.contentView else { return }
        func label(_ text: String, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat = 240, _ size: CGFloat = 13) -> NSTextField {
            let l = NSTextField(labelWithString: text)
            l.frame = NSRect(x: x, y: y, width: width, height: size + 8)
            l.font = .systemFont(ofSize: size)
            c.addSubview(l)
            return l
        }
        func button(_ title: String, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ action: Selector) {
            let b = NSButton(title: title, target: self, action: action)
            b.bezelStyle = .rounded
            b.frame = NSRect(x: x, y: y, width: width, height: 28)
            c.addSubview(b)
        }

        label("把常用功能放在桌宠旁边", 18, 480, 250, 14).font = .systemFont(ofSize: 14, weight: .semibold)
        let clock = label("🕒", 18, 452, 250, 12)
        clock.textColor = .secondaryLabelColor
        clockLabel = clock

        let weather = label("天气：正在获取…", 18, 410, 180, 12)
        weather.textColor = .secondaryLabelColor
        weatherLabel = weather
        button("🌦 更新天气", 18, 374, 82, #selector(updateWeather))
        button("❄️ 演示下雪", 104, 374, 82, #selector(demoSnow))
        button("☀️ 演示晴天", 190, 374, 78, #selector(demoSun))
        button("🌠 演示流星雨", 18, 340, 82, #selector(demoStars))
        button("🌸 演示樱花", 104, 340, 82, #selector(demoCherry))
        button("🍁 演示枫叶", 190, 340, 78, #selector(demoMaple))
        button("🌧 演示下雨", 18, 306, 82, #selector(demoRain))
        button("▶️ 依次演示", 104, 306, 82, #selector(demoSequence))

        label("互动养成", 18, 268, 240, 12).textColor = .secondaryLabelColor
        button("🥬 投喂大葱", 18, 232, 118, #selector(feed))
        button("🎁 送礼物", 150, 232, 118, #selector(gift))
        button("💬 聊聊天", 18, 196, 118, #selector(chat))
        let mood = label("心情：", 150, 200, 118, 12)
        mood.textColor = .secondaryLabelColor
        moodLabel = mood

        label("桌面陪伴", 18, 156, 240, 12).textColor = .secondaryLabelColor
        button("📝 打开便签", 18, 120, 118, #selector(note))
        let rest = NSButton(checkboxWithTitle: "☕ 休息提醒", target: self, action: #selector(toggleRestReminder))
        rest.frame = NSRect(x: 150, y: 120, width: 118, height: 28)
        c.addSubview(rest)
        restButton = rest
        button("⚙️ 更多设置", 18, 76, 118, #selector(settings))

        let hint = label("形象切换仍在右键菜单和设置中", 18, 28, 250, 11)
        hint.textColor = .secondaryLabelColor
        hint.alignment = .center

        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateLabels() }
        }
    }

    private func reposition() {
        guard let panel, let pet = pet, let window = pet.window else { return }
        let gap: CGFloat = 12
        var origin = NSPoint(x: window.frame.maxX + gap, y: window.frame.maxY - panel.frame.height)
        if let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(window.frame) }) {
            let visible = screen.visibleFrame
            if origin.x + panel.frame.width > visible.maxX { origin.x = window.frame.minX - panel.frame.width - gap }
            origin.y = min(origin.y, visible.maxY - panel.frame.height)
            origin.y = max(origin.y, visible.minY)
        }
        panel.setFrameOrigin(origin)
        lastPanelOrigin = origin
    }

    func petWindowMoved() {
        guard !syncingWindows, panel?.isVisible == true else { return }
        syncingWindows = true
        reposition()
        syncingWindows = false
    }

    private func panelWindowMoved() {
        guard !syncingWindows, let panel, let pet = pet, let window = pet.window else { return }
        let now = panel.frame.origin
        let dx = now.x - lastPanelOrigin.x
        let dy = now.y - lastPanelOrigin.y
        guard abs(dx) > 0.1 || abs(dy) > 0.1 else { return }
        syncingWindows = true
        window.setFrameOrigin(NSPoint(x: window.frame.minX + dx, y: window.frame.minY + dy))
        lastPanelOrigin = now
        syncingWindows = false
    }

    private func updateLabels() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        clockLabel?.stringValue = "🕒 " + formatter.string(from: Date())
        if let pet { moodLabel?.stringValue = "心情:\(pet.mood)/100" }
        weatherLabel?.stringValue = WeatherController.shared.status
        restButton?.state = restTimer == nil ? .off : .on
    }

    func weatherUpdated() { updateLabels() }

    @objc private func feed() { pet?.feed() }
    @objc private func gift() { pet?.giveGift() }
    @objc private func chat() { pet?.chatAction() }
    @objc private func note() { NotePanelController.shared.show() }
    @objc private func updateWeather() { WeatherController.shared.request() }
    @objc private func demoSnow() { WeatherController.shared.demo(.snow) }
    @objc private func demoRain() { WeatherController.shared.demo(.rain) }
    @objc private func demoSun() { WeatherController.shared.demo(.sun) }
    @objc private func demoStars() { WeatherController.shared.demo(.stars) }
    @objc private func demoCherry() { WeatherController.shared.demo(.cherry) }
    @objc private func demoMaple() { WeatherController.shared.demo(.maple) }
    @objc private func demoSequence() { WeatherController.shared.demoSequence() }
    @objc private func settings() {
        guard let pet else { return }
        SettingsController.shared.show(pet: pet)
    }

    @objc private func toggleRestReminder() {
        if let restTimer {
            restTimer.invalidate()
            self.restTimer = nil
            pet?.say("好，休息提醒先关掉啦～")
        } else {
            restTimer = Timer.scheduledTimer(withTimeInterval: 50 * 60, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let pet = self.pet else { return }
                    pet.say("坐了很久了吧？起来走走、看看远处吧～")
                    SoundManager.shared.play("voice_07")
                }
            }
            pet?.say("我会每隔一段时间提醒你休息哦～")
        }
        updateLabels()
    }
}

@MainActor
final class NotePanelController: NSObject {
    static let shared = NotePanelController()
    private var window: NSWindow?
    private var textView: NSTextView?

    func show() {
        if window == nil { build() }
        textView?.string = defaults.string(forKey: "deskNote") ?? ""
        window?.makeKeyAndOrderFront(nil)
    }

    private func build() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 260),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "初音便签"
        w.isReleasedWhenClosed = false
        let scroll = NSScrollView(frame: NSRect(x: 16, y: 52, width: 288, height: 180))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        let tv = NSTextView(frame: NSRect(x: 0, y: 0, width: 288, height: 180))
        tv.font = .systemFont(ofSize: 14)
        scroll.documentView = tv
        w.contentView?.addSubview(scroll)
        textView = tv
        let save = NSButton(title: "保存便签", target: self, action: #selector(save))
        save.bezelStyle = .rounded
        save.frame = NSRect(x: 16, y: 14, width: 100, height: 28)
        w.contentView?.addSubview(save)
        window = w
    }

    @objc private func save() {
        defaults.set(textView?.string ?? "", forKey: "deskNote")
        window?.orderOut(nil)
    }
}

// MARK: - 设置面板

@MainActor
final class SettingsController: NSObject {
    static let shared = SettingsController()
    private var win: NSWindow?
    private weak var pet: PetController?
    private var skinPopup: NSPopUpButton!
    private var sizeSlider: NSSlider!
    private var opacitySlider: NSSlider!
    private var hourlyCheck: NSButton!
    private var loginCheck: NSButton!
    private var moodLabel: NSTextField!
    private var soundCheck: NSButton!
    private var volumeSlider: NSSlider!

    func show(pet: PetController) {
        self.pet = pet
        if win == nil { build() }
        syncValues()
        win?.center()
        win?.makeKeyAndOrderFront(nil)
    }

    private func build() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 368),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "初音桌宠 · 设置"
        w.isReleasedWhenClosed = false
        let c = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 368))
        w.contentView = c
        win = w

        func label(_ t: String, _ x: CGFloat, _ y: CGFloat, _ wd: CGFloat = 90) -> NSTextField {
            let l = NSTextField(labelWithString: t)
            l.frame = NSRect(x: x, y: y, width: wd, height: 20)
            l.font = .systemFont(ofSize: 13)
            c.addSubview(l)
            return l
        }
        // 形象
        _ = label("形象", 24, 284)
        skinPopup = NSPopUpButton(frame: NSRect(x: 110, y: 280, width: 200, height: 26))
        skinPopup.addItems(withTitles: ["涂鸦喏葱版（蜡笔）", "Q版（可爱）", "标准立绘（厚涂）"])
        skinPopup.target = self
        skinPopup.action = #selector(skinChanged)
        c.addSubview(skinPopup)

        // 大小
        _ = label("大小", 24, 244)
        sizeSlider = NSSlider(value: 280, minValue: 160, maxValue: 420, target: self, action: #selector(sizeChanged))
        sizeSlider.frame = NSRect(x: 110, y: 238, width: 200, height: 24)
        c.addSubview(sizeSlider)

        // 透明度
        _ = label("透明度", 24, 204)
        opacitySlider = NSSlider(value: 1.0, minValue: 0.4, maxValue: 1.0, target: self, action: #selector(opacityChanged))
        opacitySlider.frame = NSRect(x: 110, y: 198, width: 200, height: 24)
        c.addSubview(opacitySlider)

        // 心情
        _ = label("心情值", 24, 164)
        moodLabel = NSTextField(labelWithString: "")
        moodLabel.frame = NSRect(x: 110, y: 160, width: 200, height: 20)
        moodLabel.font = .systemFont(ofSize: 13)
        c.addSubview(moodLabel)
        let resetBtn = NSButton(title: "重置心情", target: self, action: #selector(resetMood))
        resetBtn.bezelStyle = .rounded
        resetBtn.frame = NSRect(x: 290, y: 154, width: 88, height: 28)
        c.addSubview(resetBtn)

        // 整点问候
        hourlyCheck = NSButton(checkboxWithTitle: "整点报时问候", target: self, action: #selector(hourlyChanged))
        hourlyCheck.frame = NSRect(x: 24, y: 122, width: 200, height: 22)
        c.addSubview(hourlyCheck)

        // 开机自启
        loginCheck = NSButton(checkboxWithTitle: "开机自动启动", target: self, action: #selector(loginChanged))
        loginCheck.frame = NSRect(x: 24, y: 94, width: 200, height: 22)
        c.addSubview(loginCheck)

        // 退出按钮
        let quit = NSButton(title: "退出桌宠", target: PetController.self, action: #selector(PetController.quitAction))
        quit.bezelStyle = .rounded
        quit.frame = NSRect(x: 24, y: 20, width: 100, height: 30)
        c.addSubview(quit)

        let about = NSButton(title: "关于 / 版权说明", target: self, action: #selector(aboutTap))
        about.bezelStyle = .rounded
        about.frame = NSRect(x: 140, y: 20, width: 140, height: 30)
        c.addSubview(about)

        // 语音
        _ = label("语音", 24, 62)
        soundCheck = NSButton(checkboxWithTitle: "初音语音", target: self, action: #selector(soundChanged))
        soundCheck.frame = NSRect(x: 110, y: 58, width: 110, height: 22)
        c.addSubview(soundCheck)
        volumeSlider = NSSlider(value: 0.8, minValue: 0, maxValue: 1, target: self, action: #selector(volumeChanged))
        volumeSlider.frame = NSRect(x: 224, y: 56, width: 150, height: 24)
        c.addSubview(volumeSlider)
    }

    private func syncValues() {
        skinPopup.selectItem(at: ["crayon", "chibi", "standard"].firstIndex(of: defaults.string(forKey: kSkin) ?? "crayon") ?? 0)
        sizeSlider.doubleValue = defaults.object(forKey: kSize) == nil ? 280 : Double(defaults.float(forKey: kSize))
        opacitySlider.doubleValue = defaults.object(forKey: kOpacity) == nil ? 1.0 : Double(defaults.float(forKey: kOpacity))
        hourlyCheck.state = defaults.object(forKey: kHourly) == nil || defaults.bool(forKey: kHourly) ? .on : .off
        loginCheck.state = LaunchAgent.isInstalled() ? .on : .off
        soundCheck.state = SoundManager.shared.enabled ? .on : .off
        soundCheck.isEnabled = SoundManager.shared.available
        soundCheck.title = SoundManager.shared.available ? "初音语音" : "本版无语音"
        volumeSlider.isEnabled = SoundManager.shared.available
        volumeSlider.doubleValue = Double(SoundManager.shared.volume)
        let m = pet?.mood ?? 60
        moodLabel.stringValue = m >= 75 ? "😊 开心 (\(m)/100)" : (m >= 30 ? "🙂 平静 (\(m)/100)" : "😢 低落 (\(m)/100) · 多点点她")
    }

    @objc private func skinChanged() {
        let names = ["crayon", "chibi", "standard"]
        defaults.set(names[skinPopup.indexOfSelectedItem], forKey: kSkin)
        pet?.loadSkin()
        pet?.rebuildWindow()
        pet?.refreshBaseImage()
    }

    @objc private func sizeChanged() {
        defaults.set(Float(sizeSlider.doubleValue), forKey: kSize)
        pet?.rebuildWindow()
    }

    @objc private func opacityChanged() {
        defaults.set(Float(opacitySlider.doubleValue), forKey: kOpacity)
        pet?.window?.alphaValue = CGFloat(opacitySlider.doubleValue)
    }

    @objc private func soundChanged() {
        defaults.set(soundCheck.state == .on, forKey: kSoundOn)
        if soundCheck.state != .on { SoundManager.shared.stop() }
    }

    @objc private func volumeChanged() {
        defaults.set(Float(volumeSlider.doubleValue), forKey: kSoundVolume)
        if SoundManager.shared.enabled { SoundManager.shared.play("voice_09") } // 试听
    }

    @objc private func resetMood() {
        pet?.mood = 60
        pet?.refreshBaseImage()
        syncValues()
    }

    @objc private func hourlyChanged() {
        defaults.set(hourlyCheck.state == .on, forKey: kHourly)
    }

    @objc private func loginChanged() {
        let on = loginCheck.state == .on
        let ok = LaunchAgent.set(on, bundleURL: Bundle.main.bundleURL)
        if !ok { loginCheck.state = .off }
    }

    @objc private func aboutTap() { showAbout() }

    func showAbout() {
        let alert = NSAlert()
        alert.messageText = "初音桌宠 MikuDeskPet"
        alert.informativeText = """
        一只住在你桌面上的初音未来 ♪

        · 三套 AI 生成立绘；此公开版本不包含语音
        · 心情系统：多点她、投喂大葱会开心；冷落会低落
        · 深夜 0-7 点会自动睡觉；整点会报时问候

        Hatsune Miku, © Crypton Future Media, Inc. 2007
        角色二创：CC BY-NC 3.0，仅限非商业用途。
        https://creativecommons.org/licenses/by-nc/3.0/
        官方规则：https://piapro.net/intl/en_for_creators.html
        原创代码采用 MIT；本项目为非官方同人项目。
        """
        alert.runModal()
    }
}

// MARK: - 开机自启（LaunchAgent）

enum LaunchAgent {
    static var plistPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/LaunchAgents/\(kBundleID).plist").path
    }

    static func isInstalled() -> Bool {
        FileManager.default.fileExists(atPath: plistPath)
    }

    @discardableResult
    static func set(_ on: Bool, bundleURL: URL) -> Bool {
        let fm = FileManager.default
        if on {
            let bin = bundleURL.appendingPathComponent("Contents/MacOS/MikuDeskPet").path
            guard fm.fileExists(atPath: bin) else { return false }
            let dir = (plistPath as NSString).deletingLastPathComponent
            try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
            let dict: NSDictionary = [
                "Label": kBundleID,
                "ProgramArguments": [bin],
                "RunAtLoad": true,
                "KeepAlive": false,
            ]
            guard dict.write(toFile: plistPath, atomically: true) else { return false }
            _ = runLaunchctl(["bootstrap", "gui/\(getuid())", plistPath])
            return true
        } else {
            _ = runLaunchctl(["bootout", "gui/\(getuid())/\(kBundleID)"])
            try? fm.removeItem(atPath: plistPath)
            return true
        }
    }

    private static func runLaunchctl(_ args: [String]) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run(); p.waitUntilExit(); return p.terminationStatus == 0 }
        catch { return false }
    }
}

// MARK: - 入口

let app = NSApplication.shared

// Resource/render smoke test: no preferences, location requests or login changes.
if CommandLine.arguments.contains("--smoke-test") {
    var count = 0
    guard !SoundManager.shared.available, !SoundManager.shared.enabled else {
        fputs("SMOKE: public bundle unexpectedly contains voice resources\n", stderr); exit(1)
    }
    for skin in ["standard", "chibi", "crayon"] {
        guard SkinSet(name: skin) != nil else { fputs("SMOKE: missing skin\n", stderr); exit(1) }
        for state in ["idle", "blink", "happy", "sad", "sleep"] {
            autoreleasepool {
                guard let clip = PetMotionClip(skin: skin, state: state), clip.frames.count == 48 else {
                    fputs("SMOKE: invalid animation\n", stderr); exit(1)
                }
                let frame = clip.frame(at: 0.5)
                guard frame.bitmap.pixelsWide > 0 else { exit(1) }
                count += clip.frames.count
            }
        }
    }
    print("SMOKE: 15 skins/states, \(count) animation frames decoded; no audio")
    exit(0)
}

// 单实例保护
if let id = Bundle.main.bundleIdentifier,
   NSRunningApplication.runningApplications(withBundleIdentifier: id).count > 1 {
    fputs("MikuDeskPet already running\n", stderr)
    exit(0)
}

var controller: PetController?
DispatchQueue.main.async {
    controller = PetController()
    controller?.start()
    if CommandLine.arguments.contains("--demo-speech") {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { controller?.demoSpeech() }
    }
    if CommandLine.arguments.contains("--demo-motion") {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { controller?.demoMotion() }
    }
}
app.run()
