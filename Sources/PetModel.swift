import AppKit
import SwiftUI

/// What the pet is "feeling". Drives its face and animation.
enum Mood: Equatable {
    case idle, happy, sleepy, thinking, focus, alert
}

/// Fixed geometry of the overlay window. Everything is anchored to the
/// bottom-right corner, so these numbers are offsets from that corner.
enum Layout {
    static let windowSize = CGSize(width: 380, height: 580)
    /// Gap between the window and the screen corner, so Pip isn't jammed into it.
    static let screenInset: CGFloat = 24
    static let petSize: CGFloat = 104
    static let margin: CGFloat = 14
    static let cardSize = CGSize(width: 340, height: 430)
    static var cardBottom: CGFloat { margin + petSize + 6 }

    /// Pet hit-box in window coordinates (AppKit: origin bottom-left).
    static var petRect: CGRect {
        CGRect(x: windowSize.width - margin - petSize, y: margin, width: petSize, height: petSize)
    }
    static var cardRect: CGRect {
        CGRect(x: windowSize.width - margin - cardSize.width, y: cardBottom,
               width: cardSize.width, height: cardSize.height)
    }
}

/// Fast-changing eye state, kept separate so cursor tracking only redraws the pet.
@MainActor
final class EyeState: ObservableObject {
    /// Where the eyes look, each axis in -1...1.
    @Published var look = CGVector(dx: 0, dy: 0)
    @Published var blink = false
}

/// Shared state for the pet, its speech bubble and the feature card.
@MainActor
final class PetModel: ObservableObject {
    static let name = "Pip"

    @Published var expanded = false
    @Published var hovering = false
    @Published var speech: String?
    @Published private(set) var mood: Mood = .idle

    let eyes = EyeState()
    let pomodoro = Pomodoro()
    let chat = ChatModel()
    let notes = NotesModel()

    var lastPetted = Date.distantPast
    var idleSince = Date()

    private var speechClear: DispatchWorkItem?

    init() {
        pomodoro.onFinish = { [weak self] phase in
            Chiptune.levelUp()
            self?.say(phase == .focus ? "QUEST COMPLETE! Take a break." : "Break's over. Back to it?", for: 8)
        }
        chat.onReply = { [weak self] text in
            guard let self, !self.expanded else { return }
            self.say(String(text.prefix(140)) + (text.count > 140 ? "…" : ""), for: 10)
        }
    }

    #if SNAPSHOT
    func forceMood(_ m: Mood) { mood = m }
    #endif

    /// Recompute the mood. Cheap; only publishes when it actually changes.
    func refreshMood() {
        let next = computeMood()
        if next != mood { mood = next }
    }

    private func computeMood() -> Mood {
        if pomodoro.justFinished { return .alert }
        if chat.isLoading { return .thinking }
        if Date().timeIntervalSince(lastPetted) < 2.5 || hovering { return .happy }
        if pomodoro.isRunning && pomodoro.phase == .focus { return .focus }
        if Date().timeIntervalSince(idleSince) > 10 * 60 { return .sleepy }
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 0 && hour < 6 { return .sleepy }
        return .idle
    }

    func say(_ text: String, for seconds: TimeInterval = 5) {
        speechClear?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { speech = text }
        let work = DispatchWorkItem { [weak self] in
            withAnimation(.easeOut(duration: 0.25)) { self?.speech = nil }
        }
        speechClear = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    func petClicked() {
        lastPetted = Date()
        if pomodoro.justFinished { pomodoro.acknowledge() }
        refreshMood()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) { expanded.toggle() }
        if expanded { speech = nil }
    }

    func greeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning! Click me if you need anything."
        case 12..<17: return "Hi! I'll be down here in the corner."
        case 17..<22: return "Good evening! I'm here if you need me."
        default: return "Up late? I'll keep you company."
        }
    }

    static let quips = [
        "Stretch break? Your shoulders will thank you.",
        "Drink some water to restore HP.",
        "Look at something far away for 20 seconds.",
        "You're doing great.",
        "Ready for a new quest? Click me for a focus timer.",
    ]
}
