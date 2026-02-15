import Foundation

final class AssistantFramePlayer {
    private(set) var manifest: AssistantManifest
    private(set) var currentAnimationName: String
    private(set) var currentGlobalFrameIndex: Int = 0

    private var elapsedInFrame: TimeInterval = 0
    private var localFrameIndex: Int = 0
    private var shouldLoopOverride: Bool?
    private var loopDelay: TimeInterval = 0
    private var pendingLoopDelay: TimeInterval = 0

    init(manifest: AssistantManifest, initialAnimationName: String? = nil) throws {
        guard !manifest.frames.isEmpty else {
            throw AssistantsError.emptyFrames
        }
        self.manifest = manifest

        if let initialAnimationName {
            guard manifest.animations.contains(where: { $0.name == initialAnimationName }) else {
                throw AssistantsError.invalidInput("Unknown animation name '\(initialAnimationName)'.")
            }
            self.currentAnimationName = initialAnimationName
        } else if let firstAnimation = manifest.animations.first {
            self.currentAnimationName = firstAnimation.name
        } else {
            self.currentAnimationName = "all"
            self.manifest.animations = [
                AssistantAnimationClip(name: "all", startFrame: 0, frameCount: manifest.frames.count, loops: true)
            ]
        }

        guard let animation = self.animation(named: self.currentAnimationName) else {
            throw AssistantsError.invalidInput("Unable to initialize animation player.")
        }
        self.currentGlobalFrameIndex = animation.startFrame
    }

    var currentFrame: AssistantFrame {
        manifest.frames[currentGlobalFrameIndex]
    }

    func play(_ animation: ClippyAnimation, restart: Bool = true) throws {
        try play(named: animation.rawValue, restart: restart)
    }

    func play(_ animation: CatAnimation, restart: Bool = true) throws {
        try play(named: animation.rawValue, restart: restart)
    }

    func play(_ animation: RockyAnimation, restart: Bool = true) throws {
        try play(named: animation.rawValue, restart: restart)
    }

    func play(named name: String, restart: Bool = true) throws {
        guard let animation = self.animation(named: name) else {
            throw AssistantsError.invalidInput("Unknown animation name '\(name)'.")
        }

        currentAnimationName = name
        if restart {
            localFrameIndex = 0
            elapsedInFrame = 0
            pendingLoopDelay = 0
        } else {
            localFrameIndex = min(localFrameIndex, max(animation.frameCount - 1, 0))
        }
        currentGlobalFrameIndex = animation.startFrame + localFrameIndex
    }

    func configurePlayback(looping: Bool, loopDelay: TimeInterval) {
        shouldLoopOverride = looping
        self.loopDelay = max(0, loopDelay)
    }

    func update(deltaTime: TimeInterval) {
        guard deltaTime > 0, let animation = self.animation(named: currentAnimationName) else {
            return
        }
        guard animation.frameCount > 0 else {
            return
        }

        var remaining = deltaTime
        let shouldLoop = shouldLoopOverride ?? animation.loops

        while remaining > 0 {
            if pendingLoopDelay > 0 {
                let consumed = min(remaining, pendingLoopDelay)
                pendingLoopDelay -= consumed
                remaining -= consumed
                if pendingLoopDelay > 0 {
                    break
                }
                localFrameIndex = 0
                currentGlobalFrameIndex = animation.startFrame + localFrameIndex
                elapsedInFrame = 0
                continue
            }

            let currentDuration = max(currentFrame.duration, 1.0 / 120.0)
            let timeToAdvance = currentDuration - elapsedInFrame
            if remaining < timeToAdvance {
                elapsedInFrame += remaining
                remaining = 0
                break
            }

            remaining -= timeToAdvance
            elapsedInFrame = 0

            let nextIndex = localFrameIndex + 1
            if nextIndex < animation.frameCount {
                localFrameIndex = nextIndex
            } else if shouldLoop {
                if loopDelay > 0 {
                    pendingLoopDelay = loopDelay
                    localFrameIndex = animation.frameCount - 1
                } else {
                    localFrameIndex = 0
                }
            } else {
                localFrameIndex = animation.frameCount - 1
                remaining = 0
                elapsedInFrame = 0
                currentGlobalFrameIndex = animation.startFrame + localFrameIndex
                break
            }
            currentGlobalFrameIndex = animation.startFrame + localFrameIndex
        }
    }

    private func animation(named name: String) -> AssistantAnimationClip? {
        manifest.animations.first(where: { $0.name == name })
    }
}
