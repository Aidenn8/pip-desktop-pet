import SwiftUI

// MARK: - Sprite data

typealias Pix = (Int, Int, Character)

/// Pip as 8-bit pixel art: a 21x18 grid where each cell is one "pixel".
/// The body is fixed; the face (eyes, tear marks, nose, mouth, cheeks) is drawn on top per mood.
enum Sprite {
    static let cell: CGFloat = 4
    static var cols: Int { body[0].count }
    static var rows: Int { body.count }
    static var width: CGFloat { cell * CGFloat(cols) }
    static var height: CGFloat { cell * CGFloat(rows) }
    /// Space between the sprite and the edge of the pet area, used on both the right and bottom.
    static var sideGap: CGFloat { (Layout.petSize - width) / 2 }

    /// A little sitting red panda with its ringed tail curled up behind it.
    static let body: [String] = [
        ".KK............KK....",
        "KWWK..........KWWK...",
        "KWNWK........KWNWK...",
        "KWNNRKKKKKKKKRNNWK...",
        ".KRRRRRRRRRRRRRRK....",
        "KRRWWWRRRRRRWWWRRK...",
        "KRRRRRRRRRRRRRRRRKKK.",
        "KRRRRRRRRRRRRRRRRKQQK",
        "KRRRRRRRRRRRRRRRRKQQK",
        "KRRRRRRRRRRRRRRRRKRRK",
        "KWRRRRWWWWWWRRRRWKRRK",
        "KWWRRWWWWWWWWRRWWKQQK",
        ".KWWWWWWWWWWWWWWKKQQK",
        "..KKKRRRRRRRRKKK.KRRK",
        ".KBBBKBBBBBBKBBBKKRRK",
        ".KBBBKBBBBBBKBBBKKQQK",
        "..KBBBKKKKKKBBBK.KQQK",
        "...KKK......KKK...KK.",
    ]

    /// Softened about 18% from full saturation so Pip doesn't pop too loudly on screen.
    static let colors: [Character: Color] = [
        "K": Color(red: 0.17, green: 0.08, blue: 0.05),  // outline
        "R": Color(red: 0.80, green: 0.44, blue: 0.28),  // rust fur
        "Q": Color(red: 0.95, green: 0.73, blue: 0.52),  // light tail ring
        "W": Color(red: 0.99, green: 0.96, blue: 0.91),  // white markings
        "N": Color(red: 0.36, green: 0.19, blue: 0.14),  // inner ear
        "B": Color(red: 0.25, green: 0.14, blue: 0.11),  // dark legs and chest
        "T": Color(red: 0.50, green: 0.25, blue: 0.18),  // tear marks
        "P": Color(red: 0.08, green: 0.04, blue: 0.03),  // eye
        "E": .white,                                     // eye shine
        "C": Color(red: 1.00, green: 0.63, blue: 0.69),  // cheek
        "M": Color(red: 0.55, green: 0.22, blue: 0.26),  // open mouth
    ]

    /// Left columns of the two eyes, and their top row.
    static let leftEye = 3, rightEye = 12, eyeTop = 7
    static let cheeks = [(2, 11), (15, 11)]

    /// Face pixels for a mood: (column, row, color key).
    static func face(mood: Mood, gaze: (x: Int, y: Int), blink: Bool) -> [Pix] {
        let e = eyeTop
        let K: Character = "K", P: Character = "P", E: Character = "E"
        let T: Character = "T", M: Character = "M"
        var px: [Pix] = []

        // Dark "tear marks" running down from each eye, a red panda signature.
        px += [(4, e + 3, T), (4, e + 4, T), (13, e + 3, T), (13, e + 4, T)]

        // Big dark eyes with a white shine that shifts toward the cursor.
        for ex in [leftEye, rightEye] {
            switch mood {
            case .happy:  // ^ ^
                px += [(ex, e + 1, K), (ex + 1, e, K), (ex + 2, e + 1, K)]
            case .curious:  // sparkly eyes looking right at you: two glints
                for r in e...(e + 2) { for c in 0..<3 { px.append((ex + c, r, P)) } }
                px += [(ex, e, E), (ex + 2, e + 2, E)]
            case .sleepy:  // peacefully closed
                px += [(ex, e + 1, K), (ex + 1, e + 1, K), (ex + 2, e + 1, K)]
            case _ where blink:
                px += [(ex, e + 1, K), (ex + 1, e + 1, K), (ex + 2, e + 1, K)]
            case .focus:  // half-closed, determined
                for r in (e + 1)...(e + 2) { for c in 0..<3 { px.append((ex + c, r, P)) } }
                px.append((ex + gaze.x, e + 1, E))
            case .alert:  // startled: white eyes, tiny pupils
                for r in e...(e + 2) { for c in 0..<3 { px.append((ex + c, r, E)) } }
                px.append((ex + 1, e + 1, P))
            default:  // idle / thinking: shine follows the cursor
                let g = mood == .thinking ? (x: 2, y: 0) : gaze
                for r in e...(e + 2) { for c in 0..<3 { px.append((ex + c, r, P)) } }
                px.append((ex + g.x, e + g.y, E))
            }
        }

        // Nose on the white muzzle, mouth just below.
        px += [(8, e + 3, K), (9, e + 3, K)]
        let m = e + 4
        switch mood {
        case .happy:
            px += [(7, m, K), (8, m, M), (9, m, M), (10, m, K), (8, m + 1, M), (9, m + 1, M)]
        case .curious:  // small curious "oh"
            px += [(8, m, M), (9, m, M)]
        case .alert:
            px += [(8, m, M), (9, m, M), (8, m + 1, M), (9, m + 1, M)]
        case .thinking:
            px += [(9, m + 1, K), (10, m + 1, K)]
        case .sleepy, .focus:
            px += [(8, m + 1, K), (9, m + 1, K)]
        case .idle:
            px += [(7, m, K), (8, m + 1, K), (9, m + 1, K), (10, m, K)]
        }
        return px
    }
}

// MARK: - Pet

/// The creature, drawn as a still pixel-art pose. Motion (the two-frame idle
/// bob, hops) is applied by Core Animation to this view's layer in main.swift,
/// so SwiftUI only redraws on real changes: a blink, a gaze shift, a mood change.
struct PetView: View {
    @ObservedObject var m: PetModel
    @ObservedObject var eyes: EyeState

    var body: some View {
        let mood = m.mood
        let gaze = (x: Int(eyes.look.dx) + 1, y: 1 - Int(eyes.look.dy))
        let face = Sprite.face(mood: mood, gaze: gaze, blink: eyes.blink)
        let cheekAlpha = mood == .happy ? 1.0 : (mood == .curious ? 0.6 : 0.0)

        ZStack(alignment: .topLeading) {
            Canvas { ctx, _ in
                let s = Sprite.cell
                func dot(_ c: Int, _ r: Int, _ color: Color) {
                    ctx.fill(Path(CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s, height: s)), with: .color(color))
                }
                for (r, row) in Sprite.body.enumerated() {
                    for (c, ch) in row.enumerated() where ch != "." {
                        dot(c, r, Sprite.colors[ch]!)
                    }
                }
                for (c, r) in Sprite.cheeks {
                    dot(c, r, Sprite.colors["C"]!.opacity(cheekAlpha))
                }
                for (c, r, ch) in face { dot(c, r, Sprite.colors[ch]!) }
            }
            .frame(width: Sprite.width, height: Sprite.height)
            // Same gap below the sprite as beside it, so Pip sits evenly in the corner.
            .offset(x: Sprite.sideGap, y: Layout.petSize - Sprite.height - Sprite.sideGap)

            // Mood decorations, top-right of the head
            Group {
                switch mood {
                case .sleepy: Zzz()
                case .thinking: ThinkingDots()
                case .alert: AlertMark()
                default:
                    if m.hasUnread { UnreadDot() }
                }
            }
            .offset(x: Layout.petSize - (mood == .sleepy ? 27 : 30), y: 0)
        }
        .frame(width: Layout.petSize, height: Layout.petSize, alignment: .topLeading)
        .contentShape(Rectangle())
    }
}

/// Status window to the left of Pip while a timer runs: phase, time and a segment bar.
struct TimerHUD: View {
    @ObservedObject var pomodoro: Pomodoro

    var body: some View {
        if pomodoro.isRunning || pomodoro.remaining < pomodoro.total {
            let color = pomodoro.isRunning ? (pomodoro.phase == .focus ? GameColor.red : GameColor.green) : GameColor.dim
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(!pomodoro.isRunning ? "PAUSED" : (pomodoro.phase == .focus ? "FOCUS" : "REST"))
                        .font(GameFont.title(7)).foregroundStyle(color)
                    Text(pomodoro.label)
                        .font(GameFont.title(9)).foregroundStyle(GameColor.text)
                }
                SegmentBar(progress: pomodoro.progress, segments: 10, color: color, height: 6)
            }
            .padding(.horizontal, 11).padding(.vertical, 10)
            .pixelWindow(shadow: false)
        }
    }
}

/// Sleeping z's. All three stay on screen, dimmed, and one at a time (small to
/// big) brightens, like a soft wave drifting upward. Calm enough to ignore, but
/// still alive. Steps every 1.5 seconds, only while asleep.
struct Zzz: View {
    static let step: TimeInterval = 1.5
    static let dim = 0.55

    var body: some View {
        TimelineView(.periodic(from: .now, by: Self.step)) { ctx in
            let lit = Int(ctx.date.timeIntervalSinceReferenceDate / Self.step) % 3
            ZStack(alignment: .topLeading) {
                Text("z").font(GameFont.title(7)).offset(x: 0, y: 14).opacity(lit == 0 ? 1 : Self.dim)
                Text("z").font(GameFont.title(8)).offset(x: 7, y: 6).opacity(lit == 1 ? 1 : Self.dim)
                Text("Z").font(GameFont.title(10)).offset(x: 15, y: -3).opacity(lit == 2 ? 1 : Self.dim)
            }
            .foregroundStyle(GameColor.text)
            .shadow(color: GameColor.outline, radius: 0, x: 1, y: 1)
        }
    }
}

/// "..." counting up while waiting for Claude. Ticks a few times a second, only while visible.
struct ThinkingDots: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.3)) { ctx in
            let n = Int(ctx.date.timeIntervalSinceReferenceDate / 0.3) % 4
            Text(String(repeating: ".", count: n).padding(toLength: 3, withPad: " ", startingAt: 0))
                .font(GameFont.title(8))
                .foregroundStyle(GameColor.text)
                .padding(.horizontal, 7).padding(.top, 6).padding(.bottom, 9)
                .pixelWindow(shadow: false)
        }
    }
}

struct AlertMark: View {
    var body: some View {
        Text("!")
            .font(GameFont.title(12))
            .foregroundStyle(GameColor.red)
            .padding(.horizontal, 9).padding(.vertical, 8)
            .pixelWindow(fill: GameColor.yellow, border: GameColor.yellow, shadow: false)
    }
}

// MARK: - Speech

/// Text that types itself out one character at a time, like an RPG dialog box.
struct TypewriterText: View {
    static var enabled = true
    let text: String
    var animate = true
    var font: Font = GameFont.body(19)
    var color: Color = GameColor.text
    var onFinish: (() -> Void)?
    @State private var shown = Int.max

    var body: some View {
        // Hidden full text reserves the final size so the box doesn't grow as it types.
        Text(text).font(font).opacity(0)
            .overlay(alignment: .topLeading) {
                Text(String(text.prefix(shown))).font(font).foregroundStyle(color)
            }
            .fixedSize(horizontal: false, vertical: true)
            .task(id: text) {
                guard animate, Self.enabled else { shown = Int.max; return }
                for i in 0...text.count {
                    shown = i
                    try? await Task.sleep(nanoseconds: 22_000_000)
                    if Task.isCancelled { break }
                }
                shown = Int.max
                if !Task.isCancelled { onFinish?() }
            }
    }
}

/// Small pixel dot meaning "a reply from Claude is waiting". Click Pip to read it.
struct UnreadDot: View {
    var body: some View {
        Rectangle()
            .fill(GameColor.cyan)
            .frame(width: 8, height: 8)
            .padding(2)
            .background(Rectangle().fill(GameColor.outline))
            .offset(x: 12, y: 8)
    }
}
