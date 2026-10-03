import Foundation

/// A single scratchpad note, saved to Application Support as plain text.
@MainActor
final class NotesModel: ObservableObject {
    @Published var text: String { didSet { scheduleSave() } }
    private var saveWork: DispatchWorkItem?

    static var fileURL: URL { AppPaths.support.appendingPathComponent("notes.txt") }

    init() { text = (try? String(contentsOf: Self.fileURL, encoding: .utf8)) ?? "" }

    /// Write any pending edit right away (used when the app quits).
    func saveNow() {
        saveWork?.cancel()
        saveWork = nil
        try? text.write(to: Self.fileURL, atomically: true, encoding: .utf8)
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let snapshot = text
        let work = DispatchWorkItem { try? snapshot.write(to: Self.fileURL, atomically: true, encoding: .utf8) }
        saveWork = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.6, execute: work)
    }
}

enum AppPaths {
    static var support: URL {
        #if SNAPSHOT
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("DesktopPetSnapshot", isDirectory: true)
        #else
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DesktopPet", isDirectory: true)
        #endif
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
