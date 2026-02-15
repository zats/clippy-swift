import Foundation

public enum AssistantsError: LocalizedError {
    case emptyFrames
    case unsupportedPlatform(String)
    case decodeFailed(String)
    case encodeFailed(String)
    case ioFailed(String)
    case invalidInput(String)

    public var errorDescription: String? {
        switch self {
        case .emptyFrames:
            return "No frames were produced."
        case let .unsupportedPlatform(message):
            return message
        case let .decodeFailed(message):
            return "Image decode failed: \(message)"
        case let .encodeFailed(message):
            return "Image encode failed: \(message)"
        case let .ioFailed(message):
            return "I/O failed: \(message)"
        case let .invalidInput(message):
            return "Invalid input: \(message)"
        }
    }
}
