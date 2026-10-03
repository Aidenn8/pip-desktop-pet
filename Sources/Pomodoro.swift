import AppKit
import SwiftUI

/// A simple focus/break timer. Ticks once a second only while running.
@MainActor
final class Pomodoro: ObservableObject {
    enum Phase { case focus, rest }

    @Published var phase: Phase = .focus
    @Published var isRunning = false
    @Published var remaining: TimeInterval = 25 * 60
    @Published var justFinished = false
    @Published var focusMinutes: Int = UserDefaults.standard.object(forKey: "focusMinutes") as? Int ?? 25 {
        didSet { UserDefaults.standard.set(focusMinutes, forKey: "focusMinutes"); if !isRunning && phase == .focus { remaining = total } }
    }
    @Published var restMinutes: Int = UserDefaults.standard.object(forKey: "restMinutes") as? Int ?? 5 {
        didSet { UserDefaults.standard.set(restMinutes, forKey: "restMinutes"); if !isRunning && phase == .rest { remaining = total } }
    }

    var onFinish: ((Phase) -> Void)?
    private var endDate: Date?
    private var timer: Timer?

    init() { remaining = TimeInterval(focusMinutes * 60) }

    var total: TimeInterval { TimeInterval((phase == .focus ? focusMinutes : restMinutes) * 60) }
    var progress: Double { total > 0 ? 1 - remaining / total : 0 }
    var label: String {
        let s = max(0, Int(remaining.rounded(.up)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    func start() {
        justFinished = false
        endDate = Date().addingTimeInterval(remaining)
        isRunning = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.tick() }
        }
    }

    func pause() {
        tick()
        isRunning = false
        timer?.invalidate(); timer = nil
    }

    func reset() {
        pause()
        justFinished = false
        phase = .focus
        remaining = total
    }

    func skip() {
        pause()
        phase = phase == .focus ? .rest : .focus
        remaining = total
    }

    func acknowledge() { justFinished = false }

    private func tick() {
        guard isRunning, let endDate else { return }
        remaining = max(0, endDate.timeIntervalSinceNow)
        if remaining <= 0 {
            let finished = phase
            isRunning = false
            timer?.invalidate(); timer = nil
            phase = phase == .focus ? .rest : .focus
            remaining = total
            justFinished = true
            onFinish?(finished)
        }
    }
}
