import SwiftUI

/// Everything inside the transparent overlay window.
struct RootView: View {
    @ObservedObject var m: PetModel

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.clear

            if m.expanded {
                FeatureCard(m: m)
                    .frame(width: Layout.cardSize.width, height: Layout.cardSize.height)
                    .padding(.trailing, Layout.margin)
                    .padding(.bottom, Layout.cardBottom)
                    .transition(.scale(scale: 0.85, anchor: .bottomTrailing).combined(with: .opacity))
            } else if let speech = m.speech {
                SpeechBubble(text: speech)
                    .padding(.trailing, Layout.margin + 4)
                    .padding(.bottom, Layout.margin + Layout.petSize - 2)
                    .transition(.scale(scale: 0.8, anchor: .bottomTrailing).combined(with: .opacity))
                    .allowsHitTesting(false)
            }

            // The pet itself is a separate view layered on top (see main.swift).
            PetGround(pomodoro: m.pomodoro)
                .padding(.trailing, Layout.margin)
                .padding(.bottom, Layout.margin)
                .allowsHitTesting(false)
        }
        .frame(width: Layout.windowSize.width, height: Layout.windowSize.height)
    }
}

struct FeatureCard: View {
    @ObservedObject var m: PetModel
    @AppStorage("tab") private var tab = Tab.chat

    enum Tab: String, CaseIterable, Identifiable {
        case chat = "Chat", timer = "Timer", notes = "Notes"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { m.expanded = false }
                } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            switch tab {
            case .chat: ChatTab(chat: m.chat)
            case .timer: TimerTab(pomodoro: m.pomodoro)
            case .notes: NotesTab(notes: m.notes)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        )
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.primary.opacity(0.08)))
    }
}

// MARK: - Chat

struct ChatTab: View {
    @ObservedObject var chat: ChatModel
    @State private var draft = ""
    @State private var keyDraft = ""
    @State private var showSettings = false
    @FocusState private var focused: Bool

    var body: some View {
        if !chat.hasKey || showSettings {
            keySetup
        } else {
            VStack(spacing: 8) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            if chat.lines.isEmpty {
                                Text("Ask \(PetModel.name) anything. Replies come from Claude.")
                                    .font(.callout).foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity).padding(.top, 40)
                            }
                            ForEach(chat.lines) { line in ChatBubble(line: line).id(line.id) }
                            if chat.isLoading {
                                Text("\(PetModel.name) is thinking…").font(.caption).foregroundStyle(.secondary).id("loading")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: chat.lines.count) { _ in
                        if let last = chat.lines.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                    }
                }
                HStack(spacing: 6) {
                    TextField("Message \(PetModel.name)…", text: $draft, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...4)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06)))
                        .focused($focused)
                        .onSubmit(send)
                    Button(action: send) {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 22))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(draft.isEmpty || chat.isLoading ? Color.secondary : Palette.body)
                    .disabled(draft.isEmpty || chat.isLoading)
                }
                HStack {
                    Button("Clear chat") { chat.clear() }.disabled(chat.lines.isEmpty)
                    Spacer()
                    Button("API key…") { keyDraft = ""; showSettings = true }
                }
                .buttonStyle(.link).font(.caption)
            }
            .onAppear { focused = true }
        }
    }

    private func send() {
        let text = draft
        draft = ""
        chat.send(text)
    }

    private var keySetup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Connect to Claude").font(.headline)
            Text("Paste an Anthropic API key to chat. Get one at console.anthropic.com. It's saved only on this Mac.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            SecureField("sk-ant-…", text: $keyDraft)
                .textFieldStyle(.roundedBorder)
                .onSubmit(saveKey)
            HStack {
                Button("Save", action: saveKey).keyboardShortcut(.defaultAction).disabled(keyDraft.isEmpty)
                if chat.hasKey {
                    Button("Cancel") { showSettings = false }
                    Spacer()
                    Button("Remove key", role: .destructive) { chat.forgetKey(); showSettings = false }
                }
            }
            Spacer()
        }
    }

    private func saveKey() {
        guard !keyDraft.isEmpty else { return }
        chat.saveKey(keyDraft)
        keyDraft = ""
        showSettings = false
    }
}

struct ChatBubble: View {
    let line: ChatModel.Line
    var body: some View {
        HStack {
            if line.fromUser { Spacer(minLength: 40) }
            Text(line.text)
                .textSelection(.enabled)
                .font(.system(size: 13))
                .foregroundStyle(line.fromUser ? Color.white : (line.isError ? Color.red : Color.primary))
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(line.fromUser ? Palette.bodyDark : Color.primary.opacity(0.07))
                )
            if !line.fromUser { Spacer(minLength: 40) }
        }
    }
}

// MARK: - Timer

struct TimerTab: View {
    @ObservedObject var pomodoro: Pomodoro

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            ZStack {
                Circle().stroke(Color.primary.opacity(0.08), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: pomodoro.progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.4), value: pomodoro.progress)
                VStack(spacing: 2) {
                    Text(pomodoro.label)
                        .font(.system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
                    Text(pomodoro.phase == .focus ? "Focus" : "Break")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            .frame(width: 170, height: 170)

            HStack(spacing: 10) {
                Button(pomodoro.isRunning ? "Pause" : "Start") {
                    pomodoro.isRunning ? pomodoro.pause() : pomodoro.start()
                }
                .keyboardShortcut(.defaultAction)
                Button("Reset") { pomodoro.reset() }
                Button(pomodoro.phase == .focus ? "Skip to break" : "Skip break") { pomodoro.skip() }
            }
            .controlSize(.large)

            HStack(spacing: 16) {
                Stepper("Focus \(pomodoro.focusMinutes)m", value: $pomodoro.focusMinutes, in: 1...120)
                Stepper("Break \(pomodoro.restMinutes)m", value: $pomodoro.restMinutes, in: 1...60)
            }
            .font(.caption)
            .disabled(pomodoro.isRunning)
            Spacer(minLength: 0)
        }
    }

    private var color: Color { pomodoro.phase == .focus ? Palette.focus : Palette.rest }
}

// MARK: - Notes

struct NotesTab: View {
    @ObservedObject var notes: NotesModel
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextEditor(text: $notes.text)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
            Text("Saved automatically.").font(.caption2).foregroundStyle(.secondary)
        }
    }
}
