import AppKit
import CoreText
import SwiftUI

// MARK: - Fonts

/// Two open-license pixel fonts bundled in Resources/Fonts:
/// Press Start 2P for titles and buttons, VT323 for readable body text.
enum GameFont {
    static func register() {
        let dirs = [Bundle.main.resourceURL?.appendingPathComponent("Fonts"),
                    URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources/Fonts")]
        for dir in dirs.compactMap({ $0 }) {
            guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for url in files where url.pathExtension == "ttf" {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
            return
        }
    }

    /// Chunky arcade font. Looks best at multiples of 8.
    static func title(_ size: CGFloat) -> Font { .custom("PressStart2P-Regular", fixedSize: size) }
    /// Terminal-style font that stays readable for longer text. Ligatures are
    /// switched off, since VT323 otherwise draws "fi" as one squashed glyph.
    static func body(_ size: CGFloat) -> Font {
        let features: [[CFString: Any]] = [[
            kCTFontFeatureTypeIdentifierKey: kLigaturesType,
            kCTFontFeatureSelectorIdentifierKey: kCommonLigaturesOffSelector,
        ]]
        let desc = CTFontDescriptorCreateWithAttributes([
            kCTFontNameAttribute: "VT323-Regular",
            kCTFontFeatureSettingsAttribute: features,
        ] as CFDictionary)
        return Font(CTFontCreateWithFontDescriptor(desc, size, nil))
    }
}

// MARK: - Colors

enum GameColor {
    static let window = Color(red: 0.10, green: 0.11, blue: 0.29)
    static let windowLight = Color(red: 0.17, green: 0.19, blue: 0.45)
    static let border = Color(red: 0.95, green: 0.95, blue: 0.98)
    static let outline = Color(red: 0.03, green: 0.03, blue: 0.08)
    static let text = Color(red: 0.95, green: 0.95, blue: 0.98)
    static let dim = Color(red: 0.60, green: 0.63, blue: 0.85)
    static let yellow = Color(red: 1.00, green: 0.82, blue: 0.25)
    static let cyan = Color(red: 0.36, green: 0.88, blue: 0.90)
    static let red = Color(red: 1.00, green: 0.30, blue: 0.30)
    static let green = Color(red: 0.36, green: 0.84, blue: 0.36)
    static let field = Color(red: 0.05, green: 0.06, blue: 0.16)
}

// MARK: - Pixel window frame

/// A rectangle with stepped, notched corners like an 8-bit dialog window.
struct NotchedRect: Shape {
    var step: CGFloat = 3
    func path(in r: CGRect) -> Path {
        let s = step
        var p = Path()
        p.move(to: CGPoint(x: r.minX + s, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - s, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - s, y: r.minY + s))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + s))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - s))
        p.addLine(to: CGPoint(x: r.maxX - s, y: r.maxY - s))
        p.addLine(to: CGPoint(x: r.maxX - s, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + s, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + s, y: r.maxY - s))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - s))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + s))
        p.addLine(to: CGPoint(x: r.minX + s, y: r.minY + s))
        p.closeSubpath()
        return p
    }
}

/// Classic RPG window: dark outline, white border, deep blue fill.
struct PixelWindow: ViewModifier {
    var fill: Color = GameColor.window
    var border: Color = GameColor.border
    var shadow = true

    func body(content: Content) -> some View {
        content.background(
            ZStack {
                if shadow { NotchedRect(step: 3).fill(Color.black.opacity(0.45)).offset(x: 4, y: 4) }
                NotchedRect(step: 3).fill(GameColor.outline)
                NotchedRect(step: 3).fill(border).padding(2)
                NotchedRect(step: 2)
                    .fill(LinearGradient(colors: [GameColor.windowLight, fill], startPoint: .top, endPoint: .bottom))
                    .padding(5)
            }
        )
    }
}

extension View {
    func pixelWindow(fill: Color = GameColor.window, border: Color = GameColor.border, shadow: Bool = true) -> some View {
        modifier(PixelWindow(fill: fill, border: border, shadow: shadow))
    }
}

/// Chunky button that drops into its shadow when pressed.
struct PixelButtonStyle: ButtonStyle {
    var color: Color = GameColor.yellow
    var textColor: Color = GameColor.outline

    func makeBody(configuration: Configuration) -> some View {
        PixelButtonBody(configuration: configuration, color: color, textColor: textColor)
    }

    private struct PixelButtonBody: View {
        let configuration: Configuration
        let color: Color
        let textColor: Color
        @Environment(\.isEnabled) private var enabled

        var body: some View {
            let pressed = configuration.isPressed
            configuration.label
                .font(GameFont.title(8))
                .foregroundStyle(textColor)
                .padding(.horizontal, 9).padding(.vertical, 7)
                .background(
                    ZStack {
                        NotchedRect(step: 2).fill(GameColor.outline)
                        NotchedRect(step: 2).fill(color).padding(2)
                        Rectangle().fill(Color.white.opacity(0.35)).frame(height: 2)
                            .frame(maxHeight: .infinity, alignment: .top).padding(.horizontal, 4).padding(.top, 3)
                    }
                )
                .background(NotchedRect(step: 2).fill(GameColor.outline).offset(y: pressed ? 0 : 3))
                .offset(y: pressed ? 3 : 0)
                .opacity(enabled ? 1 : 0.4)
                .contentShape(Rectangle())
        }
    }
}

/// A row of square segments, like a health or experience bar.
struct SegmentBar: View {
    let progress: Double
    var segments = 20
    var color: Color = GameColor.red
    var height: CGFloat = 12

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<segments, id: \.self) { i in
                Rectangle()
                    .fill(Double(i) < (progress * Double(segments)).rounded(.down) ? color : GameColor.field)
                    .overlay(Rectangle().fill(Color.white.opacity(0.3)).frame(height: 2), alignment: .top)
            }
        }
        .frame(height: height)
        .padding(3)
        .background(Rectangle().fill(GameColor.outline))
    }
}

// MARK: - Chiptune sounds

/// Tiny square-wave sound effects, synthesized at launch. No audio files needed.
@MainActor
enum Chiptune {
    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "soundOn") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "soundOn") }
    }

    private static let blipSound = make([(988, 0.035), (1319, 0.05)], volume: 0.18)
    private static let levelUpSound = make([(523, 0.09), (659, 0.09), (784, 0.09), (1047, 0.22)], volume: 0.22)
    private static let closeSound = make([(784, 0.035), (523, 0.05)], volume: 0.15)

    #if SNAPSHOT
    static var allLoaded: Bool { blipSound != nil && levelUpSound != nil && closeSound != nil }
    static var levelUpDuration: TimeInterval { levelUpSound?.duration ?? 0 }
    #endif

    static func blip() { play(blipSound) }
    static func close() { play(closeSound) }
    static func levelUp() { play(levelUpSound) }

    private static func play(_ sound: NSSound?) {
        guard enabled, let sound else { return }
        sound.stop()
        sound.play()
    }

    /// Builds a WAV in memory from (frequency Hz, seconds) notes.
    private static func make(_ notes: [(Double, Double)], volume: Double) -> NSSound? {
        let rate = 22050.0
        var samples: [Int16] = []
        for (freq, dur) in notes {
            let n = Int(rate * dur)
            for i in 0..<n {
                let phase = (Double(i) * freq / rate).truncatingRemainder(dividingBy: 1)
                let env = min(1, Double(n - i) / (rate * 0.01))  // tiny fade-out to avoid clicks
                samples.append(Int16((phase < 0.5 ? 1 : -1) * volume * env * Double(Int16.max)))
            }
        }
        var data = Data()
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        let bytes = UInt32(samples.count * 2)
        data.append(contentsOf: Array("RIFF".utf8)); u32(36 + bytes)
        data.append(contentsOf: Array("WAVEfmt ".utf8)); u32(16); u16(1); u16(1)
        u32(UInt32(rate)); u32(UInt32(rate) * 2); u16(2); u16(16)
        data.append(contentsOf: Array("data".utf8)); u32(bytes)
        samples.forEach { withUnsafeBytes(of: $0.littleEndian) { data.append(contentsOf: $0) } }
        return NSSound(data: data)
    }
}
