// Renders the pet and card offscreen to PNGs for visual checks.
// Build/run: tools/snapshot.sh <outdir>
import AppKit
import SwiftUI

@MainActor
func render<V: View>(_ view: V, size: CGSize, to path: String, dark: Bool) {
    let host = NSHostingView(rootView: view.environment(\.colorScheme, dark ? .dark : .light))
    host.frame = NSRect(origin: .zero, size: size)
    let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    window.contentView = host
    host.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.4))
    let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
    host.cacheDisplay(in: host.bounds, to: rep)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

struct Backdrop<C: View>: View {
    let dark: Bool
    @ViewBuilder let content: C
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            LinearGradient(colors: dark ? [.black, Color(white: 0.2)] : [Color(white: 0.93), Color(red: 0.75, green: 0.85, blue: 0.95)],
                           startPoint: .top, endPoint: .bottom)
            content
        }
    }
}

MainActor.assumeIsolated {
    let out = CommandLine.arguments.dropFirst().first ?? "."
    _ = NSApplication.shared
    NSApp.setActivationPolicy(.prohibited)
    GameFont.register()
    TypewriterText.enabled = false

    // Every mood, pet only.
    let moods: [(String, Mood)] = [("idle", .idle), ("happy", .happy), ("sleepy", .sleepy),
                                   ("thinking", .thinking), ("focus", .focus), ("alert", .alert)]
    for (name, mood) in moods {
        let m = PetModel()
        m.forceMood(mood)
        m.eyes.look = CGVector(dx: -1, dy: 1)
        let v = Backdrop(dark: false) {
            PetView(m: m, eyes: m.eyes)
                .frame(width: Layout.petSize, height: Layout.petSize)
                .padding(8)
        }.frame(width: 120, height: 120)
        render(v, size: CGSize(width: 120, height: 120), to: "\(out)/pet-\(name).png", dark: false)
    }

    // Hovered: the curious face.
    do {
        let m = PetModel()
        m.forceMood(.curious)
        m.hovering = true
        let v = Backdrop(dark: false) { PetView(m: m, eyes: m.eyes).frame(width: Layout.petSize, height: Layout.petSize).padding(8) }
            .frame(width: 120, height: 120)
        render(v, size: CGSize(width: 120, height: 120), to: "\(out)/pet-hover.png", dark: false)
    }

    // All moods in one strip, for the README.
    let strip = HStack(spacing: 18) {
        ForEach(Array(moods.enumerated()), id: \.offset) { _, item in
            let m = PetModel()
            let _ = m.forceMood(item.1)
            let _ = { m.eyes.look = CGVector(dx: -1, dy: 0) }()
            VStack(spacing: 10) {
                PetView(m: m, eyes: m.eyes)
                Text(item.0.uppercased()).font(GameFont.title(8)).foregroundStyle(GameColor.yellow)
            }
        }
    }
    .padding(.horizontal, 30).padding(.top, 26).padding(.bottom, 22)
    .pixelWindow(shadow: false)
    .padding(10)
    render(strip, size: CGSize(width: 680, height: 170), to: "\(out)/moods.png", dark: true)

    // Full overlay: resting pet, unread-reply dot, and each card tab, in light and dark.
    for dark in [false, true] {
        let suffix = dark ? "dark" : "light"
        let m = PetModel()
        m.hasUnread = true
        let petLayer = { (m: PetModel) in
            PetView(m: m, eyes: m.eyes).padding(.trailing, Layout.margin).padding(.bottom, Layout.margin)
        }
        render(Backdrop(dark: dark) { RootView(m: m); petLayer(m) }, size: Layout.windowSize,
               to: "\(out)/overlay-unread-\(suffix).png", dark: dark)

        for tab in FeatureCard.Tab.allCases {
            UserDefaults.standard.set(tab.rawValue, forKey: "tab")
            let m = PetModel()
            m.expanded = true
            if tab == .chat {
                m.chat.lines = [
                    .init(fromUser: true, text: "What's a good way to stay focused?"),
                    .init(fromUser: false, text: "Try a 25-minute focus block with your phone in another room. I'll cheer you on from down here!"),
                ]
            }
            if tab == .timer { m.pomodoro.remaining = 17 * 60 + 42 }
            if tab == .notes { m.notes.text = "- water the plants\n- reply to emails\n- finish the report" }
            render(Backdrop(dark: dark) { RootView(m: m); petLayer(m) }, size: Layout.windowSize,
                   to: "\(out)/overlay-\(tab.rawValue.lowercased())-\(suffix).png", dark: dark)
        }
        // Timer running: HUD next to the pet
        let mt = PetModel()
        mt.pomodoro.start(); mt.pomodoro.remaining = 17 * 60 + 42
        render(Backdrop(dark: dark) { RootView(m: mt); petLayer(mt) }, size: Layout.windowSize,
               to: "\(out)/overlay-hud-\(suffix).png", dark: dark)
        mt.pomodoro.pause()

    }
}
