import Foundation

/// User choices that change how Pip looks and behaves. Saved between launches.
@MainActor
final class PetSettings: ObservableObject {
    private let defaults = UserDefaults.standard

    /// Which character Pip appears as.
    @Published var characterID: String { didSet { defaults.set(characterID, forKey: "character") } }
    /// Fall asleep (with z's) between midnight and 6 AM and after 10 idle minutes.
    @Published var naps: Bool { didSet { defaults.set(naps, forKey: "naps") } }
    /// One small sway or hop every 15 to 30 seconds.
    @Published var fidgets: Bool { didSet { defaults.set(fidgets, forKey: "fidgets") } }
    /// A quick hop when the cursor arrives.
    @Published var hoverHop: Bool { didSet { defaults.set(hoverHop, forKey: "hoverHop") } }
    /// Chiptune sound effects.
    @Published var sound: Bool { didSet { Chiptune.enabled = sound } }

    var character: PetCharacter { PetCharacter.named(characterID) }

    init() {
        characterID = defaults.string(forKey: "character") ?? PetCharacter.defaultID
        naps = defaults.object(forKey: "naps") as? Bool ?? true
        fidgets = defaults.object(forKey: "fidgets") as? Bool ?? true
        hoverHop = defaults.object(forKey: "hoverHop") as? Bool ?? true
        sound = Chiptune.enabled
    }
}
