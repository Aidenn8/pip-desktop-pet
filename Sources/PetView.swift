import SwiftUI

// MARK: - Pet

/// The creature, drawn as a still pixel-art pose. Motion (the two-frame idle
/// bob, hops) is applied by Core Animation to this view's layer in main.swift,
/// so SwiftUI only redraws on real changes: a blink, a gaze shift, a mood change.
struct PetView: View {
    @ObservedObject var m: PetModel
    @ObservedObject var eyes: EyeState
    @ObservedObject var settings: PetSettings

    init(m: PetModel, eyes: EyeState) {
        self.m = m
        self.eyes = eyes
        self.settings = m.settings
    }

    var body: some View {
        let mood = m.mood
        let character = settings.character
        let gaze = (x: Int(eyes.look.dx) + 1, y: 1 - Int(eyes.look.dy))

        ZStack(alignment: .topLeading) {
            SpriteCanvas(character: character, mood: mood, gaze: gaze, blink: eyes.blink)
                // Same gap below the sprite as beside it, so Pip sits evenly in the corner.
                .offset(x: character.sideGap, y: Layout.petSize - character.height - character.sideGap)

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

/// Draws a character's pixels for one mood. `cell` sets the size of each pixel.
struct SpriteCanvas: View {
    let character: PetCharacter
    var mood: Mood = .idle
    var gaze: (x: Int, y: Int) = (1, 1)
    var blink = false
    var cell: CGFloat = Sprite.cell

    var body: some View {
        let face = character.face(mood, gaze, blink)
        let cheekAlpha = character.cheekAlpha(mood)
        Canvas { ctx, _ in
            func dot(_ c: Int, _ r: Int, _ color: Color) {
                ctx.fill(Path(CGRect(x: CGFloat(c) * cell, y: CGFloat(r) * cell, width: cell, height: cell)),
                         with: .color(color))
            }
            for (r, row) in character.body.enumerated() {
                for (c, ch) in row.enumerated() where ch != "." {
                    if let color = character.colors[ch] { dot(c, r, color) }
                }
            }
            if let cheek = character.colors["C"], cheekAlpha > 0 {
                for (c, r) in character.cheeks { dot(c, r, cheek.opacity(cheekAlpha)) }
            }
            for (c, r, ch) in face {
                if let color = character.colors[ch] { dot(c, r, color) }
            }
        }
        .frame(width: cell * CGFloat(character.cols), height: cell * CGFloat(character.rows))
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
