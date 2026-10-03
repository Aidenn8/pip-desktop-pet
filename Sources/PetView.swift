import SwiftUI

// MARK: - Sprite data

/// Pip as 8-bit pixel art: a 20x16 grid where each cell is one "pixel".
/// The body is fixed; the face (eyes, mouth, cheeks) is drawn on top per mood.
typealias Pix = (Int, Int, Character)

enum Sprite {
    static let cell: CGFloat = 4
    static var cols: Int { body[0].count }
    static var rows: Int { body.count }
    static var width: CGFloat { cell * CGFloat(cols) }
    static var height: CGFloat { cell * CGFloat(rows) }

    /// A mint jelly slime with a leaf sprout on top.
    static let body: [String] = [
        ".....KKK....KKK.....",
        "....KGGGK..KGGGK....",
        ".....KKGGKKGGKK.....",
        "........KSSK........",
        ".....KKKKSSKKKK.....",
        "...KKLLLOOOOOOOKK...",
        "..KLLHOOOOOOOOOOOK..",
        ".KLHOOOOOOOOOOOOOOK.",
        ".KLOOOOOOOOOOOOOODK.",
        "KOOOOOOOOOOOOOOOOODK",
        "KOOOOOOOOOOOOOOOOODK",
        "KOOOOOOOOOOOOOOOOODK",
        "KDOOOOOOOOOOOOOOOODK",
        "KDDOOOOOOOOOOOOOODDK",
        ".KDDDOOOOOOOOOODDDK.",
        "..KKKKKKKKKKKKKKKK..",
    ]

    static let colors: [Character: Color] = [
        "K": Color(red: 0.11, green: 0.17, blue: 0.23),  // outline
        "D": Color(red: 0.18, green: 0.62, blue: 0.48),  // shade
        "O": Color(red: 0.31, green: 0.82, blue: 0.63),  // body
        "L": Color(red: 0.66, green: 0.96, blue: 0.84),  // highlight
        "H": Color(red: 0.92, green: 1.00, blue: 0.97),  // shine
        "G": Color(red: 0.42, green: 0.75, blue: 0.29),  // leaf
        "S": Color(red: 0.55, green: 0.35, blue: 0.17),  // stem
        "W": .white,
        "P": Color(red: 0.08, green: 0.10, blue: 0.16),  // pupil
        "C": Color(red: 1.00, green: 0.50, blue: 0.62),  // cheek
        "M": Color(red: 0.48, green: 0.12, blue: 0.17),  // open mouth
    ]

    static let leftEye = 5, rightEye = 12, eyeTop = 8
    /// Row of the mouth and cheeks, just under the eyes.
    static var mouthRow: Int { eyeTop + 4 }
    static let cheeks = [(3, eyeTop + 4), (4, eyeTop + 4), (15, eyeTop + 4), (16, eyeTop + 4)]

    /// Face pixels for a mood: (column, row, color key).
    static func face(mood: Mood, gaze: (x: Int, y: Int), blink: Bool) -> [Pix] {
        let e = eyeTop, m = mouthRow
        let K: Character = "K", M: Character = "M", W: Character = "W", P: Character = "P"
        var px: [Pix] = []
        for ex in [leftEye, rightEye] {
            switch mood {
            case .happy:  // ^ ^
                px += [(ex, e + 2, K), (ex + 1, e + 1, K), (ex + 2, e + 2, K)] as [Pix]
            case .sleepy:  // peacefully closed
                px += [(ex, e + 2, K), (ex + 1, e + 2, K), (ex + 2, e + 2, K)] as [Pix]
            case _ where blink:
                px += [(ex, e + 2, K), (ex + 1, e + 2, K), (ex + 2, e + 2, K)] as [Pix]
            case .focus:  // heavy lids, determined
                for c in 0..<3 { px.append((ex + c, e + 1, K)) }
                for r in (e + 2)...(e + 3) { for c in 0..<3 { px.append((ex + c, r, W)) } }
                px.append((ex + gaze.x, e + 2, P))
                px.append((ex + gaze.x, e + 3, P))
            case .alert:  // wide open, tiny pupils
                for r in (e - 1)...(e + 3) { for c in 0..<3 { px.append((ex + c, r, W)) } }
                px.append((ex + 1, e + 1, P))
            default:  // idle / thinking: eyes follow the cursor
                let g = mood == .thinking ? (x: 2, y: 0) : gaze
                for r in e...(e + 3) { for c in 0..<3 { px.append((ex + c, r, W)) } }
                px.append((ex + g.x, e + g.y, P))
                px.append((ex + g.x, e + g.y + 1, P))
            }
        }
        switch mood {
        case .happy:
            px += [(8, m, K), (9, m, M), (10, m, M), (11, m, K), (9, m + 1, M), (10, m + 1, M)] as [Pix]
        case .alert:
            px += [(9, m, M), (10, m, M), (9, m + 1, M), (10, m + 1, M)] as [Pix]
        case .thinking:
            px += [(10, m + 1, K), (11, m + 1, K)] as [Pix]
        case .sleepy, .focus:
            px += [(9, m + 1, K), (10, m + 1, K)] as [Pix]
        case .idle:
            px += [(8, m, K), (9, m + 1, K), (10, m + 1, K), (11, m, K)] as [Pix]
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
                default: EmptyView()
                }
            }
            .offset(x: Layout.petSize - (mood == .sleepy ? 32 : 30), y: 0)
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
        if pomodoro.isRunning {
            let color = pomodoro.phase == .focus ? GameColor.red : GameColor.green
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(pomodoro.phase == .focus ? "FOCUS" : "REST")
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
        ZStack(alignment: .bottomLeading) {
            Text("z").font(GameFont.title(8)).offset(x: 0, y: 0)
            Text("z").font(GameFont.title(10)).offset(x: 9, y: -10)
            Text("Z").font(GameFont.title(12)).offset(x: 20, y: -22)
        }
        .foregroundStyle(GameColor.text)
        .shadow(color: GameColor.outline, radius: 0, x: 1, y: 1)
        .offset(y: 30)
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

/// Dialog box above Pip, with a name tag like a game character.
struct SpeechBubble: View {
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(PetModel.name.uppercased())
                .font(GameFont.title(8))
                .foregroundStyle(GameColor.yellow)
            TypewriterText(text: text)
                .multilineTextAlignment(.leading)
            Text("▼").font(GameFont.title(7)).foregroundStyle(GameColor.yellow)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 14).padding(.top, 13).padding(.bottom, 10)
        .frame(width: 250, alignment: .leading)
        .pixelWindow()
        .overlay(alignment: .bottomTrailing) {
            // Stepped pixel tail pointing down at Pip
            VStack(spacing: 0) {
                Rectangle().fill(GameColor.border).frame(width: 12, height: 3)
                Rectangle().fill(GameColor.border).frame(width: 8, height: 3)
                Rectangle().fill(GameColor.border).frame(width: 4, height: 3)
            }
            .offset(x: -44, y: 8)
        }
    }
}
