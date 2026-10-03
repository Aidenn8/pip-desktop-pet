import AppKit
import Combine
import IOKit
import ServiceManagement
import SwiftUI

/// A borderless, transparent panel that floats above other windows (including
/// full-screen apps) and can still take keyboard input for the chat box.
final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Root of the pet's own hosting view.
struct PetHostRoot: View {
    @ObservedObject var m: PetModel
    var body: some View {
        PetView(m: m, eyes: m.eyes)
            .onTapGesture {
                m.petClicked()
                m.expanded ? Chiptune.blip() : Chiptune.close()
                (NSApp.delegate as? AppDelegate)?.boing()
            }
            .help("\(PetModel.name): click to open")
    }
}

/// This app is never "active", so views must accept the very first click
/// instead of spending it on focusing the window.
final class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = PetModel()
    var panel: PetPanel!
    var petHost: ClickThroughHostingView<PetHostRoot>!
    var moodTimer: Timer?
    var blinkWork: DispatchWorkItem?
    var statusItem: NSStatusItem!
    var pollTimer: Timer?
    var quipTimer: Timer?
    var lastMouse = NSPoint.zero
    var cancellables = Set<AnyCancellable>()
    var lidWasClosed = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        GameFont.register()
        // Recompute the mood when the timer or chat state changes. Deferred one
        // runloop turn because @Published fires before the new value is stored.
        model.pomodoro.objectWillChange.merge(with: model.chat.objectWillChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.model.refreshMood() }
            .store(in: &cancellables)
        model.$mood.removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] mood in self?.applyMotion(for: mood) }
            .store(in: &cancellables)

        makePanel()
        makeStatusItem()
        positionPanel()

        // Quit when the Mac goes to sleep. Screen lock and the screensaver
        // don't sleep the Mac, so Pip keeps running through those.
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification,
                                                          object: nil, queue: .main) { _ in
            Task { @MainActor in NSApp.terminate(nil) }
        }

        // Closing the lid doesn't always sleep the Mac (for example with an
        // external display attached), but it always changes the screen setup.
        // Quit when the lid goes from open to closed.
        lidWasClosed = Self.isLidClosed()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                let closed = Self.isLidClosed()
                defer { self.lidWasClosed = closed }
                if closed && !self.lidWasClosed { NSApp.terminate(nil); return }
                self.positionPanel()
            }
        }

        // Poll the cursor ~20x a second. This drives eye tracking, hover, and
        // click-through: the window ignores the mouse except over the pet or card.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.pollMouse() }
        }
        pollTimer?.tolerance = 0.02

        // Time-based moods (sleepy, end of a pat) are checked once a second.
        moodTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.model.refreshMood() }
        }
        moodTimer?.tolerance = 0.3
        scheduleBlink()

        quipTimer = Timer.scheduledTimer(withTimeInterval: 45 * 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard !self.model.expanded, self.model.mood == .idle else { return }
                self.model.say(PetModel.quips.randomElement()!, for: 7)
            }
        }

        #if DEBUG
        if ProcessInfo.processInfo.environment["PIP_TEST_SLEEP"] != nil {
            print("lid closed now:", Self.isLidClosed())
            model.notes.text += "\nsaved-before-sleep"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                print("posting willSleep")
                NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.willSleepNotification, object: nil)
            }
        }
        #endif

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self else { return }
            self.model.say(self.model.greeting(), for: 6)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.notes.saveNow()
    }

    /// Reads the laptop lid sensor. Always false on Macs without a lid.
    static func isLidClosed() -> Bool {
        let root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard root != 0 else { return false }
        defer { IOObjectRelease(root) }
        let value = IORegistryEntryCreateCFProperty(root, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue()
        return (value as? Bool) ?? false
    }

    private func makePanel() {
        panel = PetPanel(contentRect: NSRect(origin: .zero, size: Layout.windowSize),
                         styleMask: [.borderless, .nonactivatingPanel],
                         backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.ignoresMouseEvents = true

        let container = NSView(frame: NSRect(origin: .zero, size: Layout.windowSize))
        container.wantsLayer = true

        let root = ClickThroughHostingView(rootView: RootView(m: model))
        root.frame = container.bounds
        root.autoresizingMask = [.width, .height]
        container.addSubview(root)

        // The pet sits in its own layer so Core Animation can move it without redraws.
        petHost = ClickThroughHostingView(rootView: PetHostRoot(m: model))
        petHost.frame = Layout.petRect
        petHost.wantsLayer = true
        container.addSubview(petHost)

        panel.contentView = container
        panel.orderFrontRegardless()
        applyMotion(for: model.mood)
    }

    // MARK: Motion

    /// Motion runs in the system compositor, not in this process. Steps are
    /// discrete and snapped to the sprite's pixel size, like an 8-bit idle animation.
    func applyMotion(for mood: Mood) {
        guard let layer = petHost?.layer else { return }
        layer.removeAnimation(forKey: "bob")
        layer.removeAnimation(forKey: "jump")

        let px = Sprite.cell
        func steps(_ values: [CGFloat], duration: CFTimeInterval) -> CAKeyframeAnimation {
            let a = CAKeyframeAnimation(keyPath: "transform.translation.y")
            a.values = values
            a.calculationMode = .discrete
            a.duration = duration
            a.repeatCount = .infinity
            return a
        }

        switch mood {
        case .alert:
            layer.add(steps([0, px, px * 2, px * 3, px * 2, px], duration: 0.42), forKey: "jump")
        case .sleepy:
            break  // perfectly still, just snoozing
        case .happy, .thinking:
            layer.add(steps([0, px], duration: 0.5), forKey: "bob")
        default:
            layer.add(steps([0, px], duration: 1.1), forKey: "bob")
        }
    }

    /// A quick pixel hop when the pet is clicked.
    func boing() {
        guard let layer = petHost?.layer else { return }
        let px = Sprite.cell
        let a = CAKeyframeAnimation(keyPath: "transform.translation.y")
        a.values = [px, px * 2, px * 3, px * 2, px, 0]
        a.calculationMode = .discrete
        a.duration = 0.3
        layer.add(a, forKey: "hop")
    }

    /// Blink every few seconds, sometimes twice. Two tiny redraws per blink.
    func scheduleBlink() {
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let double = Int.random(in: 0..<4) == 0
            self.blinkOnce()
            if double { DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { self.blinkOnce() } }
            self.scheduleBlink()
        }
        blinkWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .random(in: 2.8...6.0), execute: work)
    }

    private func blinkOnce() {
        guard panel.isVisible, model.mood != .sleepy else { return }
        model.eyes.blink = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in self?.model.eyes.blink = false }
    }

    /// Pin the window to the bottom-right of the screen the user is on, above the Dock.
    func positionPanel() {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main
        guard let area = screen?.visibleFrame else { return }
        let origin = NSPoint(x: area.maxX - Layout.windowSize.width, y: area.minY)
        panel.setFrameOrigin(origin)
    }

    private func pollMouse() {
        guard panel.isVisible else { return }
        let p = NSEvent.mouseLocation
        let f = panel.frame
        let local = NSPoint(x: p.x - f.minX, y: p.y - f.minY)

        let overPet = Layout.petRect.contains(local)
        let overCard = model.expanded && Layout.cardRect.contains(local)
        let interactive = overPet || overCard
        if panel.ignoresMouseEvents == interactive { panel.ignoresMouseEvents = !interactive }
        if model.hovering != overPet { model.hovering = overPet; model.refreshMood() }

        guard p != lastMouse else { return }
        lastMouse = p
        let wasAsleep = model.mood == .sleepy
        model.idleSince = Date()
        if wasAsleep { model.refreshMood() }

        // Eyes follow the cursor. Distances are squashed so far-away motion still reads.
        // Only redraw when the gaze moves noticeably.
        let center = NSPoint(x: f.minX + Layout.petRect.midX, y: f.minY + Layout.petRect.midY)
        let dx = p.x - center.x, dy = p.y - center.y
        let dist = max(1, hypot(dx, dy))
        let strength = min(1, dist / 220)
        func snap(_ v: CGFloat) -> CGFloat { v < -0.33 ? -1 : (v > 0.33 ? 1 : 0) }
        let look = CGVector(dx: snap(dx / dist * strength), dy: snap(dy / dist * strength))
        if look != model.eyes.look { model.eyes.look = look }
    }

    // MARK: Menu bar

    private func makeStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "gamecontroller.fill", accessibilityDescription: PetModel.name)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    @objc func toggleVisible() {
        if panel.isVisible { panel.orderOut(nil) } else { positionPanel(); panel.orderFrontRegardless() }
    }
    @objc func openChat() { openTab(.chat) }
    @objc func openTimer() { openTab(.timer) }
    @objc func openNotes() { openTab(.notes) }
    @objc func startFocus() {
        model.pomodoro.reset()
        model.pomodoro.start()
        model.say("Focus mode on. You've got this!", for: 4)
    }
    @objc func moveToThisScreen() { positionPanel() }

    private func openTab(_ tab: FeatureCard.Tab) {
        UserDefaults.standard.set(tab.rawValue, forKey: "tab")
        if !panel.isVisible { positionPanel(); panel.orderFrontRegardless() }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) { model.expanded = true }
        panel.makeKey()
    }

    @objc func toggleLoginItem() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change the login item"
            alert.informativeText = "\(error.localizedDescription)\n\nYou can add DesktopPet manually in System Settings > General > Login Items."
            alert.runModal()
        }
    }

    @objc func toggleSound() {
        Chiptune.enabled.toggle()
        Chiptune.blip()
    }

    @objc func quit() { NSApp.terminate(nil) }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        func add(_ title: String, _ action: Selector, _ key: String = "") -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.target = self
            menu.addItem(item)
            return item
        }
        _ = add(panel.isVisible ? "Hide \(PetModel.name)" : "Show \(PetModel.name)", #selector(toggleVisible))
        _ = add("Move to This Screen", #selector(moveToThisScreen))
        menu.addItem(.separator())
        _ = add("Chat…", #selector(openChat))
        _ = add("Timer…", #selector(openTimer))
        _ = add("Notes…", #selector(openNotes))
        _ = add("Start \(model.pomodoro.focusMinutes)-min Focus", #selector(startFocus))
        menu.addItem(.separator())
        let sound = add("Sound Effects", #selector(toggleSound))
        sound.state = Chiptune.enabled ? .on : .off
        let login = add("Open at Login", #selector(toggleLoginItem))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(.separator())
        _ = add("Quit \(PetModel.name)", #selector(quit), "q")
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)  // no Dock icon; lives in the menu bar
    withExtendedLifetime(delegate) { app.run() }
}
