import Foundation

public enum AssistantCharacter: String, CaseIterable, Sendable {
    case clippy
    case cat
    case rocky

    public var displayName: String {
        switch self {
        case .clippy: "Clippy"
        case .cat: "Cat"
        case .rocky: "Rocky"
        }
    }

    public var resourceDirectory: String {
        displayName
    }

    public var animationNames: [String] {
        let names: [String] = switch self {
        case .clippy:
            ClippyAnimation.allCases.map(\.rawValue)
        case .cat:
            CatAnimation.allCases.map(\.rawValue)
        case .rocky:
            RockyAnimation.allCases.map(\.rawValue)
        }
        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    public func manifestURL() throws -> URL {
        try manifestURL(in: .module)
    }

    public func manifestURL(in bundle: Bundle) throws -> URL {
        guard let url = bundle.url(forResource: "manifest", withExtension: "json", subdirectory: resourceDirectory) else {
            throw AssistantsError.ioFailed("Missing bundled manifest for \(displayName).")
        }
        return url
    }

    public func loadManifest() throws -> AssistantManifest {
        try loadManifest(in: .module)
    }

    public func loadManifest(in bundle: Bundle) throws -> AssistantManifest {
        try AssistantManifestIO.load(from: manifestURL(in: bundle))
    }
}
