import Foundation

#if canImport(SwiftUI) && canImport(CoreGraphics) && canImport(ImageIO)
import CoreGraphics
import ImageIO
import SwiftUI

public final class AssistantAnimation: ObservableObject {
    @Published public private(set) var currentCharacter: AssistantCharacter?
    @Published public private(set) var currentAnimationName: String = ""
    @Published public private(set) var lastErrorDescription: String?

    @Published fileprivate var currentFrame: AssistantFrame?
    @Published fileprivate var currentImage: CGImage?
    @Published fileprivate var canvasSize: IntSize = IntSize(width: 1, height: 1)

    private var framePlayer: AssistantFramePlayer?
    private var framesRootURL: URL?
    private var atlasCache: [String: CGImage] = [:]
    private var renderedFrameCache: [Int: CGImage] = [:]
    fileprivate var lastTickDate: Date = Date()

    public init() {}

    public func play(_ animation: ClippyAnimation) {
        play(character: .clippy, animationName: animation.rawValue)
    }

    public func play(_ animation: CatAnimation) {
        play(character: .cat, animationName: animation.rawValue)
    }

    public func play(_ animation: RockyAnimation) {
        play(character: .rocky, animationName: animation.rawValue)
    }

    private func play(character: AssistantCharacter, animationName: String) {
        do {
            try ensureLoaded(character: character)
            guard let framePlayer else {
                throw AssistantsError.invalidInput("No animation player is loaded.")
            }
            switch character {
            case .clippy:
                guard let animation = ClippyAnimation(rawValue: animationName) else {
                    throw AssistantsError.invalidInput("Unknown Clippy animation '\(animationName)'.")
                }
                try framePlayer.play(animation)
            case .cat:
                guard let animation = CatAnimation(rawValue: animationName) else {
                    throw AssistantsError.invalidInput("Unknown Cat animation '\(animationName)'.")
                }
                try framePlayer.play(animation)
            case .rocky:
                guard let animation = RockyAnimation(rawValue: animationName) else {
                    throw AssistantsError.invalidInput("Unknown Rocky animation '\(animationName)'.")
                }
                try framePlayer.play(animation)
            }
            currentCharacter = character
            currentAnimationName = framePlayer.currentAnimationName
            lastErrorDescription = nil
            updateDisplayedFrame()
        } catch {
            lastErrorDescription = error.localizedDescription
        }
    }

    fileprivate func tick(now: Date, speed: Double, isPlaying: Bool, playsOnce: Bool, loopDelay: TimeInterval) {
        guard isPlaying else {
            lastTickDate = now
            return
        }
        guard let framePlayer else {
            lastTickDate = now
            return
        }

        framePlayer.configurePlayback(looping: !playsOnce, loopDelay: loopDelay)
        let dt = max(0, now.timeIntervalSince(lastTickDate)) * max(0.01, speed)
        lastTickDate = now
        framePlayer.update(deltaTime: dt)
        updateDisplayedFrame()
    }

    private func ensureLoaded(character: AssistantCharacter) throws {
        if currentCharacter == character, framePlayer != nil {
            return
        }

        let manifestURL = try character.manifestURL()
        let manifest = try character.loadManifest()
        framePlayer = try AssistantFramePlayer(manifest: manifest)
        framesRootURL = manifestURL.deletingLastPathComponent()
        canvasSize = manifest.frameCellSize
        atlasCache = [:]
        renderedFrameCache = [:]
        currentFrame = nil
        currentImage = nil
        lastTickDate = Date()
    }

    private func updateDisplayedFrame() {
        guard let framePlayer else {
            currentFrame = nil
            currentImage = nil
            return
        }

        let frame = framePlayer.currentFrame
        currentFrame = frame

        if let cached = renderedFrameCache[frame.index] {
            currentImage = cached
            return
        }
        guard let baseImage = loadAtlas(named: frame.imageName) else {
            currentImage = nil
            return
        }
        guard let rendered = renderFrameImage(baseImage: baseImage, frame: frame) else {
            currentImage = nil
            return
        }
        renderedFrameCache[frame.index] = rendered
        currentImage = rendered
    }

    private func loadAtlas(named imageName: String) -> CGImage? {
        if let cached = atlasCache[imageName] {
            return cached
        }
        guard let framesRootURL else {
            return nil
        }
        let atlasURL = framesRootURL.appendingPathComponent(imageName)
        guard
            let source = CGImageSourceCreateWithURL(atlasURL as CFURL, nil),
            let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            return nil
        }
        atlasCache[imageName] = cgImage
        return cgImage
    }

    private func renderFrameImage(baseImage: CGImage, frame: AssistantFrame) -> CGImage? {
        let source = frame.sourceRect
        if source.x == 0, source.y == 0, source.width == baseImage.width, source.height == baseImage.height {
            return baseImage
        }
        let cropRect = CGRect(x: source.x, y: source.y, width: source.width, height: source.height)
        guard
            cropRect.minX >= 0,
            cropRect.minY >= 0,
            cropRect.maxX <= CGFloat(baseImage.width),
            cropRect.maxY <= CGFloat(baseImage.height)
        else {
            return nil
        }
        return baseImage.cropping(to: cropRect)
    }
}

public struct AssistantAnimationPlayer: View {
    @ObservedObject private var animation: AssistantAnimation

    private var playbackSpeedValue: Double = 1
    private var pixelScaleValue: CGFloat = 1
    private var isPlayingValue: Bool = true
    private var checkerSize: CGFloat = 8
    private var playsOnceValue: Bool = false
    private var loopDelayValue: TimeInterval = 0
    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    public init(_ animation: AssistantAnimation) {
        self.animation = animation
    }

    public func playbackSpeed(_ value: Double) -> Self {
        var copy = self
        copy.playbackSpeedValue = max(0.01, value)
        return copy
    }

    public func pixelScale(_ value: CGFloat) -> Self {
        var copy = self
        copy.pixelScaleValue = max(1, value)
        return copy
    }

    public func playing(_ value: Bool) -> Self {
        var copy = self
        copy.isPlayingValue = value
        return copy
    }

    public func checkerSize(_ value: CGFloat) -> Self {
        var copy = self
        copy.checkerSize = max(1, value)
        return copy
    }

    public func playsOnce(_ value: Bool) -> Self {
        var copy = self
        copy.playsOnceValue = value
        return copy
    }

    public func loopDelay(_ value: TimeInterval) -> Self {
        var copy = self
        copy.loopDelayValue = max(0, value)
        return copy
    }

    public var body: some View {
        content
            .onReceive(timer) { now in
                animation.tick(
                    now: now,
                    speed: playbackSpeedValue,
                    isPlaying: isPlayingValue,
                    playsOnce: playsOnceValue,
                    loopDelay: loopDelayValue
                )
            }
    }

    @ViewBuilder
    private var content: some View {
        let canvasWidth = CGFloat(animation.canvasSize.width) * pixelScaleValue
        let canvasHeight = CGFloat(animation.canvasSize.height) * pixelScaleValue

        ZStack(alignment: .topLeading) {
            CheckerboardBackground(squareSize: checkerSize)
            if let image = animation.currentImage, let frame = animation.currentFrame {
                Image(decorative: image, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .frame(
                        width: CGFloat(frame.size.width) * pixelScaleValue,
                        height: CGFloat(frame.size.height) * pixelScaleValue,
                        alignment: .topLeading
                    )
                    .offset(
                        x: CGFloat(frame.offset.x) * pixelScaleValue,
                        y: CGFloat(frame.offset.y) * pixelScaleValue
                    )
            }
        }
        .frame(width: canvasWidth, height: canvasHeight, alignment: .topLeading)
    }
}

private struct CheckerboardBackground: View {
    let squareSize: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let columns = Int(ceil(width / squareSize))
            let rows = Int(ceil(height / squareSize))

            ZStack(alignment: .topLeading) {
                Color(white: 0.93)
                Path { path in
                    for row in 0..<rows {
                        for column in 0..<columns where (row + column).isMultiple(of: 2) {
                            let rect = CGRect(
                                x: CGFloat(column) * squareSize,
                                y: CGFloat(row) * squareSize,
                                width: squareSize,
                                height: squareSize
                            )
                            path.addRect(rect)
                        }
                    }
                }
                .fill(Color(white: 0.82))
            }
        }
    }
}
#endif
