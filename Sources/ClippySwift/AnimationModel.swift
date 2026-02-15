import Foundation

public struct IntPoint: Codable, Hashable, Sendable {
    public let x: Int
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

public struct IntSize: Codable, Hashable, Sendable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

public struct IntRect: Codable, Hashable, Sendable {
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct AssistantFrame: Codable, Hashable, Sendable {
    public let index: Int
    public let imageName: String
    public let sourceRect: IntRect
    public let trimmedRect: IntRect
    public let offset: IntPoint
    public let size: IntSize
    public let duration: TimeInterval

    public init(
        index: Int,
        imageName: String,
        sourceRect: IntRect,
        trimmedRect: IntRect,
        offset: IntPoint,
        size: IntSize,
        duration: TimeInterval
    ) {
        self.index = index
        self.imageName = imageName
        self.sourceRect = sourceRect
        self.trimmedRect = trimmedRect
        self.offset = offset
        self.size = size
        self.duration = duration
    }
}

public struct AssistantAnimationClip: Codable, Hashable, Sendable {
    public let name: String
    public let startFrame: Int
    public let frameCount: Int
    public let loops: Bool

    public init(name: String, startFrame: Int, frameCount: Int, loops: Bool) {
        self.name = name
        self.startFrame = startFrame
        self.frameCount = frameCount
        self.loops = loops
    }
}

public struct AssistantManifest: Codable, Hashable, Sendable {
    public let characterName: String
    public let frameCellSize: IntSize
    public var frames: [AssistantFrame]
    public var animations: [AssistantAnimationClip]

    public init(
        characterName: String,
        frameCellSize: IntSize,
        frames: [AssistantFrame],
        animations: [AssistantAnimationClip]
    ) {
        self.characterName = characterName
        self.frameCellSize = frameCellSize
        self.frames = frames
        self.animations = animations
    }
}
