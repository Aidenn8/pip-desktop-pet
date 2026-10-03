import SwiftUI

typealias Pix = (Int, Int, Character)

/// Size of one sprite "pixel", in points.
enum Sprite {
    static let cell: CGFloat = 4
}

/// One look Pip can take. Each is a grid of letters (one letter per pixel) plus
/// a color for each letter, and a face drawn on top for every mood.
struct PetCharacter: Identifiable {
    let id: String
    let name: String
    let body: [String]
    let colors: [Character: Color]
    let cheeks: [(Int, Int)]
    /// How strongly the cheeks blush in each mood (0 hides them).
    let cheekAlpha: (Mood) -> Double
    /// Face pixels for a mood: gaze is 0...2 on each axis, from the cursor.
    let face: (_ mood: Mood, _ gaze: (x: Int, y: Int), _ blink: Bool) -> [Pix]

    var cols: Int { body[0].count }
    var rows: Int { body.count }
    var width: CGFloat { Sprite.cell * CGFloat(cols) }
    var height: CGFloat { Sprite.cell * CGFloat(rows) }
    /// Space between the sprite and the edge of the pet area, used on both the right and bottom.
    var sideGap: CGFloat { (Layout.petSize - width) / 2 }

    static let all: [PetCharacter] = [.redPanda, .panda, .slime, .classic]
    static let defaultID = "redPanda"

    static func named(_ id: String) -> PetCharacter {
        all.first { $0.id == id } ?? .redPanda
    }
}

// MARK: - Red panda

extension PetCharacter {
    /// A little sitting red panda with its ringed tail curled up behind it.
    static let redPanda = PetCharacter(
        id: "redPanda", name: "Red Panda",
        body: RedPanda.redPandaBody, colors: RedPanda.redPandaColors,
        cheeks: [(2, 11), (15, 11)],
        cheekAlpha: { $0 == .happy ? 1.0 : ($0 == .curious ? 0.6 : 0.0) },
        face: RedPanda.face)
}

private enum RedPanda {
        static let redPandaBody: [String] = [
            ".KK............KK....",
            "KWWK..........KWWK...",
            "KWNWK........KWNWK...",
            "KWNNRKKKKKKKKRNNWK...",
            ".KRRRRRRRRRRRRRRK....",
            "KRRWWWRRRRRRWWWRRK...",
            "KRRRRRRRRRRRRRRRRKKK.",
            "KRRRRRRRRRRRRRRRRKQQK",
            "KRRRRRRRRRRRRRRRRKQQK",
            "KRRRRRRRRRRRRRRRRKRRK",
            "KWRRRRWWWWWWRRRRWKRRK",
            "KWWRRWWWWWWWWRRWWKQQK",
            ".KWWWWWWWWWWWWWWKKQQK",
            "..KKKRRRRRRRRKKK.KRRK",
            ".KBBBKBBBBBBKBBBKKRRK",
            ".KBBBKBBBBBBKBBBKKQQK",
            "..KBBBKKKKKKBBBK.KQQK",
            "...KKK......KKK...KK.",
        ]

    /// Softened about 18% from full saturation so Pip doesn't pop too loudly on screen.
        static let redPandaColors: [Character: Color] = [
            "K": Color(red: 0.17, green: 0.08, blue: 0.05),  // outline
            "R": Color(red: 0.80, green: 0.44, blue: 0.28),  // rust fur
            "Q": Color(red: 0.95, green: 0.73, blue: 0.52),  // light tail ring
            "W": Color(red: 0.99, green: 0.96, blue: 0.91),  // white markings
            "N": Color(red: 0.36, green: 0.19, blue: 0.14),  // inner ear
            "B": Color(red: 0.25, green: 0.14, blue: 0.11),  // dark legs and chest
            "T": Color(red: 0.50, green: 0.25, blue: 0.18),  // tear marks
            "P": Color(red: 0.08, green: 0.04, blue: 0.03),  // eye
            "E": .white,                                     // eye shine
            "C": Color(red: 1.00, green: 0.63, blue: 0.69),  // cheek
            "M": Color(red: 0.55, green: 0.22, blue: 0.26),  // open mouth
        ]

    static func face(mood: Mood, gaze: (x: Int, y: Int), blink: Bool) -> [Pix] {
        let e = 7, leftEye = 3, rightEye = 12
        let K: Character = "K", P: Character = "P", E: Character = "E"
        let T: Character = "T"
        var px: [Pix] = []

        // Dark "tear marks" running down from each eye, a red panda signature.
        px += [(4, e + 3, T), (4, e + 4, T), (13, e + 3, T), (13, e + 4, T)]

        // Big dark eyes with a white shine that shifts toward the cursor.
        for ex in [leftEye, rightEye] {
            switch mood {
            case .happy:  // ^ ^
                px += [(ex, e + 1, K), (ex + 1, e, K), (ex + 2, e + 1, K)]
            case .curious:  // sparkly eyes looking right at you: two glints
                for r in e...(e + 2) { for c in 0..<3 { px.append((ex + c, r, P)) } }
                px += [(ex, e, E), (ex + 2, e + 2, E)]
            case .sleepy:  // peacefully closed
                px += [(ex, e + 1, K), (ex + 1, e + 1, K), (ex + 2, e + 1, K)]
            case _ where blink:
                px += [(ex, e + 1, K), (ex + 1, e + 1, K), (ex + 2, e + 1, K)]
            case .focus:  // half-closed, determined
                for r in (e + 1)...(e + 2) { for c in 0..<3 { px.append((ex + c, r, P)) } }
                px.append((ex + gaze.x, e + 1, E))
            case .alert:  // startled: white eyes, tiny pupils
                for r in e...(e + 2) { for c in 0..<3 { px.append((ex + c, r, E)) } }
                px.append((ex + 1, e + 1, P))
            default:  // idle / thinking: shine follows the cursor
                let g = mood == .thinking ? (x: 2, y: 0) : gaze
                for r in e...(e + 2) { for c in 0..<3 { px.append((ex + c, r, P)) } }
                px.append((ex + g.x, e + g.y, E))
            }
        }

        // Nose on the white muzzle, mouth just below.
        px += [(8, e + 3, K), (9, e + 3, K)]
        return px + mouth(mood, left: 7, row: e + 4)
    }
}

/// Mouth shapes shared by every character. `left` is the leftmost of four columns.
private func mouth(_ mood: Mood, left l: Int, row m: Int) -> [Pix] {
    let K: Character = "K", M: Character = "M"
    switch mood {
    case .happy:
        return [(l, m, K), (l + 1, m, M), (l + 2, m, M), (l + 3, m, K), (l + 1, m + 1, M), (l + 2, m + 1, M)]
    case .curious:  // small curious "oh"
        return [(l + 1, m, M), (l + 2, m, M)]
    case .alert:
        return [(l + 1, m, M), (l + 2, m, M), (l + 1, m + 1, M), (l + 2, m + 1, M)]
    case .thinking:
        return [(l + 2, m + 1, K), (l + 3, m + 1, K)]
    case .sleepy, .focus:
        return [(l + 1, m + 1, K), (l + 2, m + 1, K)]
    case .idle:
        return [(l, m, K), (l + 1, m + 1, K), (l + 2, m + 1, K), (l + 3, m, K)]
    }
}

/// Big white eyes with pupils that follow the cursor, used by the slime and the
/// original creature. `top` is the eyes' top row; the mouth sits four rows below.
private func whiteEyedFace(mood: Mood, gaze: (x: Int, y: Int), blink: Bool, top e: Int) -> [Pix] {
    let K: Character = "K", W: Character = "W", P: Character = "P"
    var px: [Pix] = []
    for ex in [5, 12] {
        switch mood {
        case .happy:  // ^ ^
            px += [(ex, e + 2, K), (ex + 1, e + 1, K), (ex + 2, e + 2, K)]
        case .sleepy:  // peacefully closed
            px += [(ex, e + 2, K), (ex + 1, e + 2, K), (ex + 2, e + 2, K)]
        case _ where blink:
            px += [(ex, e + 2, K), (ex + 1, e + 2, K), (ex + 2, e + 2, K)]
        case .focus:  // heavy lids, determined
            for c in 0..<3 { px.append((ex + c, e + 1, K)) }
            for r in (e + 2)...(e + 3) { for c in 0..<3 { px.append((ex + c, r, W)) } }
            px.append((ex + gaze.x, e + 2, P))
            px.append((ex + gaze.x, e + 3, P))
        case .alert:  // wide open, tiny pupils
            for r in (e - 1)...(e + 3) { for c in 0..<3 { px.append((ex + c, r, W)) } }
            px.append((ex + 1, e + 1, P))
        case .curious:  // looking right at you
            for r in e...(e + 3) { for c in 0..<3 { px.append((ex + c, r, W)) } }
            px.append((ex + 1, e + 1, P))
            px.append((ex + 1, e + 2, P))
        default:  // idle / thinking: eyes follow the cursor
            let g = mood == .thinking ? (x: 2, y: 0) : gaze
            for r in e...(e + 3) { for c in 0..<3 { px.append((ex + c, r, W)) } }
            px.append((ex + g.x, e + g.y, P))
            px.append((ex + g.x, e + g.y + 1, P))
        }
    }
    return px + mouth(mood, left: 8, row: e + 4)
}

// MARK: - Panda

extension PetCharacter {
    /// A little sitting panda with droopy eye patches.
    static let panda = PetCharacter(
        id: "panda", name: "Panda",
        body: [
            ".KKKK..........KKKK.",
            "KXXXXK........KXXXXK",
            "KXXXKKKKKKKKKKKKXXXK",
            ".KXKWWWWWWWWWWWWKXK.",
            ".KWWWWWWWWWWWWWWWWK.",
            "KWWWWWWWWWWWWWWWWWWK",
            "KWWWWWWWWWWWWWWWWWWK",
            "KWWWWWWWWWWWWWWWWWWK",
            "KWWWWWWWWWWWWWWWWWWK",
            "KWWWWWWWWWWWWWWWWWWK",
            "KWWWWWWWWWWWWWWWWWWK",
            "KGWWWWWWWWWWWWWWWWGK",
            ".KGWWWWWWWWWWWWWWGK.",
            "..KKKGWWWWWWWWGKKK..",
            ".KXXXKWWWWWWWWKXXXK.",
            ".KXXXKWWWWWWWWKXXXK.",
            "..KXXXKKKKKKKKXXXK..",
            "...KKK........KKK...",
        ],
        colors: [
            "K": Color(red: 0.09, green: 0.09, blue: 0.12),  // outline
            "X": Color(red: 0.19, green: 0.19, blue: 0.24),  // black fur
            "W": Color(red: 0.97, green: 0.97, blue: 0.94),  // white fur
            "G": Color(red: 0.80, green: 0.80, blue: 0.78),  // fur shade
            "E": .white,                                     // eye
            "P": Color(red: 0.05, green: 0.05, blue: 0.08),  // pupil
            "C": Color(red: 1.00, green: 0.55, blue: 0.65),  // cheek
            "M": Color(red: 0.55, green: 0.15, blue: 0.20),  // open mouth
        ],
        cheeks: [(2, 11), (3, 11), (16, 11), (17, 11)],
        cheekAlpha: { $0 == .happy ? 1.0 : ($0 == .curious ? 0.8 : 0.55) },
        face: { mood, gaze, blink in
            let e = 6
            let X: Character = "X", E: Character = "E", P: Character = "P", G: Character = "G"
            var px: [Pix] = []
            // Droopy eye patches: 5x5, missing the top-outer and bottom-inner corners.
            for (left, outerTop, innerBottom) in [(3, 3, 7), (12, 16, 12)] {
                for r in e..<(e + 5) {
                    for c in left..<(left + 5) {
                        if (r == e && c == outerTop) || (r == e + 4 && c == innerBottom) { continue }
                        px.append((c, r, X))
                    }
                }
            }
            // Eyes sit in the 3x3 middle of each patch.
            for ex in [4, 13] {
                let top = e + 1
                switch mood {
                case .happy:
                    px += [(ex, top + 1, E), (ex + 1, top, E), (ex + 2, top + 1, E)]
                case .sleepy:
                    px += [(ex, top + 1, G), (ex + 1, top + 1, G), (ex + 2, top + 1, G)]
                case _ where blink:
                    px += [(ex, top + 1, G), (ex + 1, top + 1, G), (ex + 2, top + 1, G)]
                case .focus:
                    for r in (top + 1)...(top + 2) { for c in 0..<3 { px.append((ex + c, r, E)) } }
                    px.append((ex + gaze.x, top + 1, P))
                case .alert, .curious:
                    for r in top...(top + 2) { for c in 0..<3 { px.append((ex + c, r, E)) } }
                    px.append((ex + 1, top + 1, P))
                default:
                    let g = mood == .thinking ? (x: 2, y: 0) : gaze
                    for r in top...(top + 2) { for c in 0..<3 { px.append((ex + c, r, E)) } }
                    px.append((ex + g.x, top + g.y, P))
                }
            }
            px += [(9, e + 4, X), (10, e + 4, X)]  // nose
            return px + mouth(mood, left: 8, row: e + 5)
        })
}

// MARK: - Slime

extension PetCharacter {
    /// A mint jelly slime with a leaf sprout on top.
    static let slime = PetCharacter(
        id: "slime", name: "Slime",
        body: [
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
        ],
        colors: [
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
        ],
        cheeks: [(3, 12), (4, 12), (15, 12), (16, 12)],
        cheekAlpha: { $0 == .happy ? 1.0 : ($0 == .curious ? 0.8 : 0.55) },
        face: { whiteEyedFace(mood: $0, gaze: $1, blink: $2, top: 8) })
}

// MARK: - Classic

extension PetCharacter {
    /// The original orange creature with pointed ears.
    static let classic = PetCharacter(
        id: "classic", name: "Classic",
        body: [
            "..KK............KK..",
            ".KDOK..........KODK.",
            ".KDOOKKKKKKKKKKOODK.",
            ".KOOOLLLLOOOOOOOOOK.",
            "KOOLLLOOOOOOOOOOOOOK",
            "KOLLOOOOOOOOOOOOOOOK",
            "KOLOOOOOOOOOOOOOOOOK",
            "KOOOOOOOOOOOOOOOOOOK",
            "KOOOOOOOOOOOOOOOOOOK",
            "KOOOOOOOOOOOOOOOOOOK",
            "KOOOOOOOOOOOOOOOOODK",
            "KOOOOOBBBBBBBBOOOODK",
            "KDOOOBBBBBBBBBBOOODK",
            "KDOOOBBBBBBBBBBOODDK",
            ".KDOOOBBBBBBBBOOODK.",
            ".KDDOOOOOOOOOOOODDK.",
            "..KDDDKKKKKKKKDDDK..",
            "...KKK........KKK...",
        ],
        colors: [
            "K": Color(red: 0.23, green: 0.11, blue: 0.08),  // outline
            "D": Color(red: 0.77, green: 0.37, blue: 0.18),  // shade
            "O": Color(red: 0.94, green: 0.54, blue: 0.29),  // body
            "L": Color(red: 1.00, green: 0.75, blue: 0.54),  // highlight
            "B": Color(red: 1.00, green: 0.84, blue: 0.68),  // belly
            "W": .white,
            "P": Color(red: 0.10, green: 0.06, blue: 0.13),  // pupil
            "C": Color(red: 1.00, green: 0.44, blue: 0.54),  // cheek
            "M": Color(red: 0.48, green: 0.12, blue: 0.17),  // open mouth
        ],
        cheeks: [(3, 10), (4, 10), (15, 10), (16, 10)],
        cheekAlpha: { $0 == .happy ? 1.0 : ($0 == .curious ? 0.8 : 0.55) },
        face: { whiteEyedFace(mood: $0, gaze: $1, blink: $2, top: 6) })
}
