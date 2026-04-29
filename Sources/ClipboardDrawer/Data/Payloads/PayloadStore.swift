import Foundation

final class PayloadStore {
    private let directory: URL

    init(directory: URL = AppPaths.payloadsDirectory) {
        self.directory = directory
    }

    func write(data: Data, id: String, fileExtension: String) throws -> String {
        let fileURL = directory.appendingPathComponent(id).appendingPathExtension(fileExtension)
        try data.write(to: fileURL, options: [.atomic])
        return fileURL.path
    }

    func read(path: String?) -> Data? {
        guard let path else { return nil }
        return try? Data(contentsOf: URL(fileURLWithPath: path))
    }

    func duplicate(path: String?, id: String) throws -> String? {
        guard let path else {
            return nil
        }

        let sourceURL = URL(fileURLWithPath: path)
        let fileExtension = sourceURL.pathExtension
        let destinationURL = directory.appendingPathComponent(id).appendingPathExtension(fileExtension)
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL.path
    }

    func remove(path: String?) {
        guard let path else { return }
        try? FileManager.default.removeItem(atPath: path)
    }

    func clearAll() {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return
        }
        for url in contents {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
