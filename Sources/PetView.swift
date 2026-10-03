import SwiftUI

/// The creature, drawn as a still pose. Continuous motion (bobbing, breathing,
/// jumping) is applied by Core Animation to this view's layer in main.swift, so
/// the app doesn't redraw every frame. SwiftUI only redraws on real changes:
/// a blink, the eyes moving, or a mood change.
struct PetView: View {
    @ObservedObject var m: PetModel
    @ObservedObject var eyes: EyeState

    var body: some View {
        let mood = m.mood
        ZStack {
            ZStack {
                // Ears
                HStack(spacing: 30) {
                    Ear().fill(Palette.bodyDark).frame(width: 18, height: 20)
                        .rotationEffect(.degrees(mood == .happy ? -30 : -18))
                    Ear().fill(Palette.bodyDark).frame(width: 18, height: 20)
                        .rotationEffect(.degrees(mood == .happy ? 30 : 18))
                }
                .offset(y: mood == .sleepy ? -33 : -36)

                // Body
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(LinearGradient(colors: [Palette.bodyLight, Palette.body],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .stroke(Palette.bodyDark.opacity(0.55), lineWidth: 1.5)
                    )
                    .frame(width: 80, height: 70)
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 2)

                // Belly highlight
                Ellipse().fill(Color.white.opacity(0.22)).frame(width: 40, height: 22).offset(y: 18)

                // Face
                VStack(spacing: 5) {
                    HStack(spacing: 16) {
                        EyeView(mood: mood, look: eyes.look, blink: eyes.blink)
                        EyeView(mood: mood, look: eyes.look, blink: eyes.blink)
                    }
                    MouthView(mood: mood).frame(width: 16, height: 8)
                }
                .offset(x: eyes.look.dx * 2, y: -4 - eyes.look.dy * 1.5)

                // Cheeks
                HStack(spacing: 44) {
                    Circle().fill(Palette.cheek).frame(width: 9, height: 6)
                    Circle().fill(Palette.cheek).frame(width: 9, height: 6)
                }
                .offset(y: 6)
                .opacity(mood == .happy ? 0.95 : 0.55)
            }
            .scaleEffect(m.hovering ? 1.05 : 1, anchor: .bottom)
            .offset(y: 6)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: m.hovering)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: mood)
            .animation(.easeOut(duration: 0.08), value: eyes.blink)

            // Decorations per mood
            switch mood {
            case .sleepy: Zzz().offset(x: 32, y: -34)
            case .thinking: ThinkingDots().offset(x: 36, y: -38)
            case .alert:
                Text("!").font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.focus).offset(x: 38, y: -34)
            default: EmptyView()
            }
        }
        .frame(width: Layout.petSize, height: Layout.petSize)
        .contentShape(Rectangle())
    }
}

/// Things that stay put under the pet: its shadow, the focus ring and the timer badge.
struct PetGround: View {
    @ObservedObject var pomodoro: Pomodoro

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.22))
                .frame(width: 58, height: 9)
                .blur(radius: 2)
                .offset(y: 44)

            if pomodoro.isRunning || pomodoro.remaining < pomodoro.total {
                Circle()
                    .trim(from: 0, to: pomodoro.progress)
                    .stroke(pomodoro.phase == .focus ? Palette.focus : Palette.rest,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 100, height: 100)
                    .opacity(0.85)
            }
        }
        .frame(width: Layout.petSize, height: Layout.petSize)
        .overlay(alignment: .bottomLeading) {
            if pomodoro.isRunning {
                Text(pomodoro.label)
                    .font(.system(size: 10.5, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(pomodoro.phase == .focus ? Palette.focus : Palette.rest))
                    .offset(x: -4, y: 2)
            }
        }
    }
}

enum Palette {
    static let body = Color(red: 0.93, green: 0.55, blue: 0.38)
    static let bodyLight = Color(red: 0.99, green: 0.74, blue: 0.56)
    static let bodyDark = Color(red: 0.78, green: 0.40, blue: 0.27)
    static let cheek = Color(red: 1.0, green: 0.45, blue: 0.5)
    static let focus = Color(red: 0.95, green: 0.35, blue: 0.3)
    static let rest = Color(red: 0.3, green: 0.72, blue: 0.5)
}

struct Ear: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.minY), control: CGPoint(x: r.minX, y: r.minY + 4))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY), control: CGPoint(x: r.maxX, y: r.minY + 4))
        p.closeSubpath()
        return p
    }
}

struct EyeView: View {
    let mood: Mood
    let look: CGVector
    let blink: Bool

    var body: some View {
        switch mood {
        case .sleepy:
            Arc(up: false).stroke(Color.black.opacity(0.75), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                .frame(width: 13, height: 5)
                .frame(width: 16, height: 18)
        case .happy:
            Arc(up: true).stroke(Color.black.opacity(0.8), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                .frame(width: 13, height: 7)
                .frame(width: 16, height: 18)
        default:
            let big = mood == .alert
            ZStack {
                Ellipse().fill(Color.white).frame(width: big ? 17 : 15, height: big ? 20 : 18)
                Circle().fill(Color.black.opacity(0.88))
                    .frame(width: mood == .focus ? 7 : 8.5, height: mood == .focus ? 7 : 8.5)
                    .overlay(Circle().fill(Color.white).frame(width: 2.6, height: 2.6).offset(x: -1.5, y: -1.8))
                    .offset(x: pupil.dx * 3.2, y: pupil.dy * 4)
            }
            .scaleEffect(y: blink ? 0.08 : 1)
            .frame(width: 16, height: 18)
        }
    }

    private var pupil: CGVector {
        mood == .thinking ? CGVector(dx: 0.6, dy: -0.9) : CGVector(dx: look.dx, dy: -look.dy)
    }
}

struct MouthView: View {
    let mood: Mood
    var body: some View {
        switch mood {
        case .happy, .alert:
            HalfCircle().fill(Color(red: 0.45, green: 0.12, blue: 0.12)).frame(width: 12, height: 7)
        case .thinking:
            Circle().stroke(Color.black.opacity(0.7), lineWidth: 1.8).frame(width: 5, height: 5)
        case .sleepy, .focus:
            Capsule().fill(Color.black.opacity(0.7)).frame(width: 7, height: 2)
        case .idle:
            Arc(up: false).stroke(Color.black.opacity(0.75), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                .frame(width: 9, height: 4)
        }
    }
}

/// A shallow arc. `up` draws ^ (happy eyes); otherwise draws a smile.
struct Arc: Shape {
    let up: Bool
    func path(in r: CGRect) -> Path {
        var p = Path()
        if up {
            p.move(to: CGPoint(x: r.minX, y: r.maxY))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY), control: CGPoint(x: r.midX, y: r.minY - r.height))
        } else {
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.midX, y: r.maxY + r.height))
        }
        return p
    }
}

struct HalfCircle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addArc(center: CGPoint(x: r.midX, y: r.minY), radius: r.width / 2,
                 startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        p.closeSubpath()
        return p
    }
}

struct Zzz: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ForEach(0..<3, id: \.self) { i in
                Text("z")
                    .font(.system(size: 10 + CGFloat(i) * 3, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .shadow(color: .black.opacity(0.5), radius: 1)
                    .offset(x: CGFloat(i) * 6, y: -CGFloat(i) * 9)
                    .opacity(1 - Double(i) * 0.2)
            }
        }
    }
}

/// Bouncing dots shown only while waiting for Claude, so its frame cost is brief.
struct ThinkingDots: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(Color.white)
                        .frame(width: 6, height: 6)
                        .offset(y: -abs(sin(t * 5 + Double(i) * 0.7)) * 4)
                }
            }
            .padding(.horizontal, 6).padding(.vertical, 5)
            .background(Capsule().fill(Color.black.opacity(0.55)))
        }
    }
}

/// The little speech bubble that pops up above the pet.
struct SpeechBubble: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12.5, weight: .medium, design: .rounded))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .frame(maxWidth: 230, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
            )
            .overlay(alignment: .bottomTrailing) {
                Triangle().fill(.regularMaterial).frame(width: 14, height: 9)
                    .rotationEffect(.degrees(180)).offset(x: -36, y: 8)
            }
    }
}

struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}
