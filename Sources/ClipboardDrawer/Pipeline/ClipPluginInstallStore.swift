import AppKit
import Foundation

@MainActor
final class ClipPluginInstallStore: ObservableObject {
    @Published private(set) var installedExternalManifests: [ClipPluginManifest] = []
    @Published var statusMessage: String?

    private let pluginsDirectory: URL
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(pluginsDirectory: URL = AppPaths.pluginsDirectory) {
        self.pluginsDirectory = pluginsDirectory
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        refresh()
    }

    var availableManifests: [ClipPluginManifest] {
        BuiltInClipPlugin.manifests + installedExternalManifests
    }

    func manifest(for id: String) -> ClipPluginManifest? {
        availableManifests.first { $0.id == id }
    }

    func refresh() {
        guard let packageURLs = try? FileManager.default.contentsOfDirectory(
            at: pluginsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            installedExternalManifests = []
            return
        }

        installedExternalManifests = packageURLs.compactMap { packageURL in
            let manifestURL = packageURL.appendingPathComponent("plugin.json")
            guard let data = try? Data(contentsOf: manifestURL),
                  let manifest = try? decoder.decode(ClipPluginManifest.self, from: data),
                  case .wasm(let path) = manifest.entrypoint,
                  FileManager.default.fileExists(atPath: packageURL.appendingPathComponent(path).path) else {
                return nil
            }
            return manifest
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func installPluginPackage(from sourceURL: URL) {
        do {
            let packageURL = try normalizedPackageURL(from: sourceURL)
            let manifestURL = packageURL.appendingPathComponent("plugin.json")
            let data = try Data(contentsOf: manifestURL)
            let manifest = try decoder.decode(ClipPluginManifest.self, from: data)
            try validate(manifest: manifest, packageURL: packageURL)

            let destinationURL = pluginsDirectory.appendingPathComponent("\(manifest.id).clipwellplugin", isDirectory: true)
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: packageURL, to: destinationURL)
            refresh()
            statusMessage = "Installed \(manifest.name). External execution is not enabled yet."
        } catch {
            statusMessage = "Plugin install failed: \(error.localizedDescription)"
        }
    }

    func chooseAndInstallPluginPackage() {
        let panel = NSOpenPanel()
        panel.title = "Install Clipwell Plugin"
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            installPluginPackage(from: url)
        }
    }

    private func normalizedPackageURL(from sourceURL: URL) throws -> URL {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw PluginInstallError.unsupportedPackage
        }
        return sourceURL
    }

    private func validate(manifest: ClipPluginManifest, packageURL: URL) throws {
        guard manifest.schemaVersion == 1 else {
            throw PluginInstallError.unsupportedSchema
        }
        guard !manifest.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !manifest.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PluginInstallError.invalidManifest
        }
        guard BuiltInClipPlugin.manifests.allSatisfy({ $0.id != manifest.id }) else {
            throw PluginInstallError.reservedPluginID
        }
        guard case .wasm(let path) = manifest.entrypoint else {
            throw PluginInstallError.unsupportedEntrypoint
        }
        guard FileManager.default.fileExists(atPath: packageURL.appendingPathComponent(path).path) else {
            throw PluginInstallError.missingEntrypoint
        }
    }
}

enum PluginInstallError: LocalizedError {
    case unsupportedPackage
    case unsupportedSchema
    case invalidManifest
    case reservedPluginID
    case unsupportedEntrypoint
    case missingEntrypoint

    var errorDescription: String? {
        switch self {
        case .unsupportedPackage:
            return "Choose an unpacked .clipwellplugin folder."
        case .unsupportedSchema:
            return "This plugin schema is not supported."
        case .invalidManifest:
            return "plugin.json is missing required fields."
        case .reservedPluginID:
            return "That plugin ID is reserved by a built-in plugin."
        case .unsupportedEntrypoint:
            return "Only WASM external plugins are supported."
        case .missingEntrypoint:
            return "The declared WASM entrypoint was not found."
        }
    }
}
