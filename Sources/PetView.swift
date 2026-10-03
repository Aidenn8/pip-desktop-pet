import SwiftUI

// MARK: - Sprite data

typealias Pix = (Int, Int, Character)

/// Pip as 8-bit pixel art: a 20x18 grid where each cell is one "pixel".
/// The body is fixed; the face (eye patches, eyes, nose, mouth, cheeks) is drawn on top per mood.
enum Sprite {
    static let cell: CGFloat = 4
    static var cols: Int { body[0].count }
    static var rows: Int { body.count }
    static var width: CGFloat { cell * CGFloat(cols) }
    static var height: CGFloat { cell * CGFloat(rows) }

    /// A little sitting panda.
    static let body: [String] = [
        ".KKKK..........KKKK.",
        "KXXXXK........KXXXXK",
        "KXXXKKKKKKKKKKKKXXXK",
        ".KXKWWWWWWWWWWWWKXK.",
        ".KWWWWWWWWWWWWWWWWK.",
        "KWWWWWWWWWWWWWWWWWWK",
        "KWWWWWWWWWWWWWWWWWWK",
        "KWWWWWWWWWWWWWWWWWWK",
        "KWWWWWWWWWWWWWWWWWWK",
        "KWWWWWWWWWWWWWWWWWWK",
        "KWWWWWWWWWWWWWWWWWWK",
        "KGWWWWWWWWWWWWWWWWGK",
        ".KGWWWWWWWWWWWWWWGK.",
        "..KKKGWWWWWWWWGKKK..",
        ".KXXXKWWWWWWWWKXXXK.",
        ".KXXXKWWWWWWWWKXXXK.",
        "..KXXXKKKKKKKKXXXK..",
        "...KKK........KKK...",
    ]

    static let colors: [Character: Color] = [
        "K": Color(red: 0.09, green: 0.09, blue: 0.12),  // outline
        "X": Color(red: 0.19, green: 0.19, blue: 0.24),  // black fur
        "W": Color(red: 0.97, green: 0.97, blue: 0.94),  // white fur
        "G": Color(red: 0.80, green: 0.80, blue: 0.78),  // fur shade
        "E": .white,                                     // eye
        "P": Color(red: 0.05, green: 0.05, blue: 0.08),  // pupil
        "C": Color(red: 1.00, green: 0.55, blue: 0.65),  // cheek
        "M": Color(red: 0.55, green: 0.15, blue: 0.20),  // open mouth
    ]

    /// Left columns of the two eye patches, and the patch's top row.
    static let leftPatch = 3, rightPatch = 12, eyeTop = 6
    static let cheeks = [(2, 11), (3, 11), (16, 11), (17, 11)]

    /// Face pixels for a mood: (column, row, color key).
    static func face(mood: Mood, gaze: (x: Int, y: Int), blink: Bool) -> [Pix] {
        let e = eyeTop
        let X: Character = "X", K: Character = "K", E: Character = "E", P: Character = "P"
        let G: Character = "G", M: Character = "M"
        var px: [Pix] = []

        // Droopy panda eye patches: 5x5, missing the top-outer and bottom-inner corners.
        for (left, outerTop, innerBottom) in [(leftPatch, leftPatch, leftPatch + 4),
                                              (rightPatch, rightPatch + 4, rightPatch)] {
            for r in e..<(e + 5) {
                for c in left..<(left + 5) {
                    if (r == e && c == outerTop) || (r == e + 4 && c == innerBottom) { continue }
                    px.append((c, r, X))
                }
            }
        }

        // Eyes sit in the 3x3 middle of each patch.
        for ex in [leftPatch + 1, rightPatch + 1] {
            let top = e + 1
            switch mood {
            case .happy:  // ^ ^
                px += [(ex, top + 1, E), (ex + 1, top, E), (ex + 2, top + 1, E)]
            case .sleepy:  // peacefully closed
                px += [(ex, top + 1, G), (ex + 1, top + 1, G), (ex + 2, top + 1, G)]
            case _ where blink:
                px += [(ex, top + 1, G), (ex + 1, top + 1, G), (ex + 2, top + 1, G)]
            case .focus:  // half-closed, determined
                for r in (top + 1)...(top + 2) { for c in 0..<3 { px.append((ex + c, r, E)) } }
                px.append((ex + gaze.x, top + 1, P))
            case .alert:  // wide open, centered pupil
                for r in top...(top + 2) { for c in 0..<3 { px.append((ex + c, r, E)) } }
                px.append((ex + 1, top + 1, P))
            default:  // idle / thinking: eyes follow the cursor
                let g = mood == .thinking ? (x: 2, y: 0) : gaze
                for r in top...(top + 2) { for c in 0..<3 { px.append((ex + c, r, E)) } }
                px.append((ex + g.x, top + g.y, P))
            }
        }

        // Nose, then mouth just below it.
        px += [(9, e + 4, X), (10, e + 4, X)]
        let m = e + 5
        switch mood {
        case .happy:
            px += [(8, m, K), (9, m, M), (10, m, M), (11, m, K), (9, m + 1, M), (10, m + 1, M)]
        case .alert:
            px += [(9, m, M), (10, m, M), (9, m + 1, M), (10, m + 1, M)]
        case .thinking:
            px += [(10, m + 1, K), (11, m + 1, K)]
        case .sleepy, .focus:
            px += [(9, m + 1, K), (10, m + 1, K)]
        case .idle:
            px += [(8, m, K), (9, m + 1, K), (10, m + 1, K), (11, m, K)]
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
        let cheekAlpha = mood == .happy ? 1.0 : 0.55

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
            .offset(x: (Layout.petSize - Sprite.width) / 2, y: Layout.petSize - Sprite.height - 6)

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

/// A pixel shadow that stays on the ground while Pip bobs.
struct PetGround: View {
    var body: some View {
        Canvas { ctx, _ in
            let shade = Color.black.opacity(0.28)
            let mid = Layout.petSize / 2
            ctx.fill(Path(CGRect(x: mid - 28, y: 0, width: 56, height: 4)), with: .color(shade))
            ctx.fill(Path(CGRect(x: mid - 20, y: 4, width: 40, height: 3)), with: .color(shade))
        }
        .frame(width: Layout.petSize, height: 7)
        .frame(width: Layout.petSize, height: Layout.petSize, alignment: .bottom)
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

struct Zzz: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Text("z").font(GameFont.title(7)).offset(x: 0, y: 14)
            Text("z").font(GameFont.title(8)).offset(x: 7, y: 6)
            Text("Z").font(GameFont.title(10)).offset(x: 15, y: -3)
        }
        .foregroundStyle(GameColor.text)
        .shadow(color: GameColor.outline, radius: 0, x: 1, y: 1)
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
