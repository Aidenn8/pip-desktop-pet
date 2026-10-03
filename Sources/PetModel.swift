import AppKit
import SwiftUI

/// What the pet is "feeling". Drives its face and animation.
enum Mood: Hashable {
    /// `curious` is the hover face: sparkly eyes looking at you and a small "oh" mouth.
    case idle, happy, curious, sleepy, thinking, focus, alert
}

/// Fixed geometry of the overlay window. Everything is anchored to the
/// bottom-right corner, so these numbers are offsets from that corner.
enum Layout {
    static let windowSize = CGSize(width: 380, height: 580)
    /// Gap between the window and the screen corner, so Pip isn't jammed into it.
    static let screenInset: CGFloat = 12
    static let petSize: CGFloat = 86
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

/// Shared state for the pet and the feature card.
@MainActor
final class PetModel: ObservableObject {
    static let name = "Pip"

    @Published var expanded = false
    @Published var hovering = false
    /// A Claude reply arrived while the card was closed.
    @Published var hasUnread = false
    @Published private(set) var mood: Mood = .idle

    let eyes = EyeState()
    let settings = PetSettings()
    let pomodoro = Pomodoro()
    let chat = ChatModel()
    let notes = NotesModel()

    /// Set by the app: the yellow and red window buttons in the menu.
    var onMinimize: (() -> Void)?
    var onQuit: (() -> Void)?

    var lastPetted = Date.distantPast
    var idleSince = Date()

    init() {
        pomodoro.onFinish = { _ in
            Chiptune.levelUp()
        }
        chat.onReply = { [weak self] _ in
            guard let self, !self.expanded else { return }
            self.hasUnread = true
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
        if Date().timeIntervalSince(lastPetted) < 2.5 { return .happy }
        if hovering { return .curious }
        if pomodoro.isRunning && pomodoro.phase == .focus { return .focus }
        if settings.naps {
            if Date().timeIntervalSince(idleSince) > 10 * 60 { return .sleepy }
            let hour = Calendar.current.component(.hour, from: Date())
            if hour >= 0 && hour < 6 { return .sleepy }
        }
        return .idle
    }

    func petClicked() {
        lastPetted = Date()
        if pomodoro.justFinished { pomodoro.acknowledge() }
        refreshMood()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) { expanded.toggle() }
        if expanded { hasUnread = false }
    }
}
