import AppKit

/// Use the bundled artwork explicitly for the running app and its control panel.
enum AppArtwork {
    static func load() -> NSImage? {
        var candidates: [URL] = []
        if let bundled = Bundle.main.url(forResource: "GlassText", withExtension: "icns") {
            candidates.append(bundled)
        }
        if let executable = Bundle.main.executableURL {
            candidates.append(executable.deletingLastPathComponent()
                .appendingPathComponent("../Resources/GlassText.icns").standardizedFileURL)
        }
        // Swift command-line builds run from the project directory.
        candidates.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Assets/AppIcon.icns"))
        return candidates.lazy.compactMap { NSImage(contentsOf: $0) }.first
    }
}
