import SwiftUI

/// Everything inside the transparent overlay window except the pet itself,
/// which sits in its own layer on top (see main.swift).
struct RootView: View {
    @ObservedObject var m: PetModel
    @ObservedObject var settings: PetSettings

    init(m: PetModel) {
        self.m = m
        self.settings = m.settings
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.clear

            if m.expanded {
                FeatureCard(m: m)
                    .frame(width: Layout.cardSize.width, height: Layout.cardSize.height)
                    .padding(.trailing, Layout.margin)
                    .padding(.bottom, Layout.cardBottom)
                    .transition(.scale(scale: 0.9, anchor: .bottomTrailing).combined(with: .opacity))
            }

            TimerHUD(pomodoro: m.pomodoro)
                .padding(.trailing, Layout.margin + Layout.petSize + 4)
                .padding(.bottom, Layout.margin + settings.character.sideGap)
                .allowsHitTesting(false)
        }
        .frame(width: Layout.windowSize.width, height: Layout.windowSize.height)
    }
}

struct FeatureCard: View {
    @ObservedObject var m: PetModel
    @AppStorage("tab") private var tab = Tab.chat

    enum Tab: String, CaseIterable, Identifiable {
        case chat = "Chat", timer = "Timer", notes = "Notes", settings = "Settings"
        var id: String { rawValue }
        var label: String {
            switch self {
            case .chat: return "TALK"
            case .timer: return "QUEST"
            case .notes: return "LOG"
            case .settings: return "SET"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 0) {
                ForEach(Tab.allCases) { t in
                    Button {
                        if tab != t { Chiptune.blip() }
                        tab = t
                    } label: {
                        HStack(spacing: 3) {
                            Text("▶").opacity(tab == t ? 1 : 0)
                            Text(t.label)
                        }
                        .font(GameFont.title(8))
                        .foregroundStyle(tab == t ? GameColor.yellow : GameColor.dim)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 4)
                }
                Button("X") {
                    Chiptune.close()
                    withAnimation(.easeOut(duration: 0.15)) { m.expanded = false }
                }
                .buttonStyle(PixelButtonStyle(color: GameColor.red, textColor: GameColor.text))
                .keyboardShortcut(.cancelAction)
            }
            Rectangle().fill(GameColor.border.opacity(0.25)).frame(height: 2)

            switch tab {
            case .chat: ChatTab(chat: m.chat)
            case .timer: TimerTab(pomodoro: m.pomodoro)
            case .notes: NotesTab(notes: m.notes)
            case .settings: SettingsTab(settings: m.settings)
            }
        }
        .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 16)
        .pixelWindow()
        .environment(\.colorScheme, .dark)
        .tint(GameColor.yellow)
    }
}

// MARK: - Chat

struct ChatTab: View {
    @ObservedObject var chat: ChatModel
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if chat.lines.isEmpty {
                            VStack(spacing: 10) {
                                Text("PIP WANTS TO TALK!").font(GameFont.title(10)).foregroundStyle(GameColor.yellow)
                                Text("Ask anything. Replies come from Claude through your Claude Code login.")
                                    .font(GameFont.body(19)).foregroundStyle(GameColor.dim)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity).padding(.top, 60)
                        }
                        ForEach(chat.lines) { line in ChatLine(line: line) { chat.markShown(line.id) }.id(line.id) }
                        if chat.isLoading {
                            HStack(spacing: 6) {
                                Text(PetModel.name.uppercased()).font(GameFont.title(8)).foregroundStyle(GameColor.yellow)
                                ThinkingText()
                            }
                            .id("loading")
                        }
                    }
                    .padding(.vertical, 4).padding(.trailing, 6)
                }
                .onChange(of: chat.lines.count) { _ in
                    if let last = chat.lines.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }
            HStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(">").font(GameFont.title(10)).foregroundStyle(GameColor.yellow)
                    TextField("", text: $draft, prompt: Text("Say something…").foregroundColor(GameColor.dim), axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(GameFont.body(19))
                        .foregroundStyle(GameColor.text)
                        .lineLimit(1...3)
                        .focused($focused)
                        .onSubmit(send)
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(Rectangle().fill(GameColor.field))
                .overlay(Rectangle().stroke(GameColor.border.opacity(0.5), lineWidth: 2))
                Button("SEND", action: send)
                    .buttonStyle(PixelButtonStyle())
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chat.isLoading)
            }
            HStack {
                Button("CLEAR") { chat.clear() }.disabled(chat.lines.isEmpty)
                    .buttonStyle(.plain)
                Spacer()
                Text("VIA CLAUDE CODE")
            }
            .font(GameFont.title(7))
            .foregroundStyle(GameColor.dim)
        }
        .onAppear { focused = true }
    }

    private func send() {
        let text = draft
        draft = ""
        chat.send(text)
    }
}

/// One line of the dialog log: a speaker tag, then the text.
struct ChatLine: View {
    let line: ChatModel.Line
    var onShown: () -> Void = {}
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(line.fromUser ? "YOU" : PetModel.name.uppercased())
                .font(GameFont.title(8))
                .foregroundStyle(line.fromUser ? GameColor.cyan : GameColor.yellow)
            if line.fromUser {
                Text(line.text).font(GameFont.body(19)).foregroundStyle(GameColor.text)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                TypewriterText(text: line.text, animate: line.isNew,
                               color: line.isError ? GameColor.red : GameColor.text,
                               onFinish: onShown)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ThinkingText: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.3)) { ctx in
            let n = Int(ctx.date.timeIntervalSinceReferenceDate / 0.3) % 4
            Text("thinking" + String(repeating: ".", count: n))
                .font(GameFont.body(19)).foregroundStyle(GameColor.dim)
        }
    }
}

// MARK: - Timer

struct TimerTab: View {
    @ObservedObject var pomodoro: Pomodoro

    var body: some View {
        let focus = pomodoro.phase == .focus
        let color = focus ? GameColor.red : GameColor.green
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            Text(focus ? "QUEST: FOCUS" : "REST AREA")
                .font(GameFont.title(11))
                .foregroundStyle(color)
            Text(pomodoro.label)
                .font(GameFont.title(36))
                .foregroundStyle(GameColor.text)
                .shadow(color: GameColor.outline, radius: 0, x: 3, y: 3)
            VStack(alignment: .leading, spacing: 6) {
                Text(focus ? "PROGRESS" : "RECOVERING")
                    .font(GameFont.title(7)).foregroundStyle(GameColor.dim)
                SegmentBar(progress: pomodoro.progress, segments: 16, color: color)
            }
            HStack(spacing: 10) {
                Button(pomodoro.isRunning ? "PAUSE" : "START") {
                    Chiptune.blip()
                    pomodoro.isRunning ? pomodoro.pause() : pomodoro.start()
                }
                .buttonStyle(PixelButtonStyle())
                .keyboardShortcut(.defaultAction)
                Button("RESET") { pomodoro.reset() }
                    .buttonStyle(PixelButtonStyle(color: GameColor.dim))
                Button("SKIP") { pomodoro.skip() }
                    .buttonStyle(PixelButtonStyle(color: GameColor.cyan))
            }
            VStack(spacing: 8) {
                MinutePicker(label: "FOCUS", value: $pomodoro.focusMinutes, range: 1...120)
                MinutePicker(label: "BREAK", value: $pomodoro.restMinutes, range: 1...60)
            }
            .disabled(pomodoro.isRunning)
            .opacity(pomodoro.isRunning ? 0.4 : 1)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}

/// "FOCUS  ◀ 25 ▶ MIN" style setting row.
struct MinutePicker: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 8) {
            Text(label).frame(width: 56, alignment: .leading).foregroundStyle(GameColor.dim)
            Button("◀") { value = max(range.lowerBound, value - (value > 10 ? 5 : 1)) }
            Text(String(format: "%3d", value)).foregroundStyle(GameColor.text).frame(width: 34)
            Button("▶") { value = min(range.upperBound, value + (value >= 10 ? 5 : 1)) }
            Text("MIN").foregroundStyle(GameColor.dim)
        }
        .font(GameFont.title(8))
        .buttonStyle(.plain)
        .foregroundStyle(GameColor.yellow)
    }
}

// MARK: - Notes

struct NotesTab: View {
    @ObservedObject var notes: NotesModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUEST LOG").font(GameFont.title(10)).foregroundStyle(GameColor.yellow)
            TextEditor(text: $notes.text)
                .font(GameFont.body(19))
                .foregroundStyle(GameColor.text)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Rectangle().fill(GameColor.field))
                .overlay(Rectangle().stroke(GameColor.border.opacity(0.5), lineWidth: 2))
            Text("AUTO-SAVED").font(GameFont.title(7)).foregroundStyle(GameColor.dim)
        }
    }
}

// MARK: - Settings

struct SettingsTab: View {
    @ObservedObject var settings: PetSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CHARACTER").font(GameFont.title(10)).foregroundStyle(GameColor.yellow)
            HStack(spacing: 8) {
                ForEach(PetCharacter.all) { character in
                    CharacterChoice(character: character, selected: settings.characterID == character.id) {
                        if settings.characterID != character.id { Chiptune.blip() }
                        settings.characterID = character.id
                    }
                }
            }

            Text("OPTIONS").font(GameFont.title(10)).foregroundStyle(GameColor.yellow)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 12) {
                PixelToggle(title: "NAPS", detail: "Sleep at night and after 10 idle minutes", isOn: $settings.naps)
                PixelToggle(title: "FIDGETS", detail: "A small sway or hop now and then", isOn: $settings.fidgets)
                PixelToggle(title: "HOVER HOP", detail: "Hop when your cursor arrives", isOn: $settings.hoverHop)
                PixelToggle(title: "SOUND", detail: "Chiptune sound effects", isOn: $settings.sound)
            }
            Spacer(minLength: 0)
        }
    }
}

/// A character tile: a small preview with its name, outlined when chosen.
struct CharacterChoice: View {
    let character: PetCharacter
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                SpriteCanvas(character: character, cell: 2)
                    .frame(height: 38, alignment: .bottom)
                Text(character.name.uppercased())
                    .font(GameFont.title(6))
                    .foregroundStyle(selected ? GameColor.yellow : GameColor.dim)
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(width: 66, height: 70)
            .background(Rectangle().fill(selected ? GameColor.windowLight : GameColor.field))
            .overlay(Rectangle().stroke(selected ? GameColor.yellow : GameColor.border.opacity(0.25), lineWidth: 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(character.name)
    }
}

/// A chunky checkbox row.
struct PixelToggle: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
            Chiptune.blip()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Rectangle().fill(GameColor.field)
                    Rectangle().stroke(GameColor.border.opacity(0.7), lineWidth: 2)
                    if isOn { Rectangle().fill(GameColor.yellow).padding(4) }
                }
                .frame(width: 16, height: 16)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(GameFont.title(8)).foregroundStyle(isOn ? GameColor.text : GameColor.dim)
                    Text(detail).font(GameFont.body(17)).foregroundStyle(GameColor.dim)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
