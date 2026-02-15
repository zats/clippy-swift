import Foundation

public enum AssistantManifestIO {
    public static func load(from url: URL) throws -> AssistantManifest {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ClippySwiftError.ioFailed("Unable to read manifest at \(url.path): \(error.localizedDescription)")
        }

        do {
            return try JSONDecoder().decode(AssistantManifest.self, from: data)
        } catch {
            throw ClippySwiftError.decodeFailed("Unable to decode manifest at \(url.path): \(error.localizedDescription)")
        }
    }

    public static func save(_ manifest: AssistantManifest, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data: Data
        do {
            data = try encoder.encode(manifest)
        } catch {
            throw ClippySwiftError.encodeFailed("Unable to encode manifest: \(error.localizedDescription)")
        }

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw ClippySwiftError.ioFailed("Unable to write manifest at \(url.path): \(error.localizedDescription)")
        }
    }
}
