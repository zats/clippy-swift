import XCTest
@testable import Assistants

final class AssistantsTests: XCTestCase {
    func testPlayerLoopsInsideCurrentAnimation() throws {
        let frame = AssistantFrame(
            index: 0,
            imageName: "frame_0000.png",
            sourceRect: IntRect(x: 0, y: 0, width: 10, height: 10),
            trimmedRect: IntRect(x: 0, y: 0, width: 10, height: 10),
            offset: IntPoint(x: 0, y: 0),
            size: IntSize(width: 10, height: 10),
            duration: 0.1
        )
        let frames = (0..<3).map { index in
            AssistantFrame(
                index: index,
                imageName: "frame_\(index).png",
                sourceRect: frame.sourceRect,
                trimmedRect: frame.trimmedRect,
                offset: frame.offset,
                size: frame.size,
                duration: frame.duration
            )
        }
        let manifest = AssistantManifest(
            characterName: "Clippy",
            frameCellSize: IntSize(width: 10, height: 10),
            frames: frames,
            animations: [AssistantAnimationClip(name: "all", startFrame: 0, frameCount: 3, loops: true)]
        )

        let player = try AssistantFramePlayer(manifest: manifest)
        XCTAssertEqual(player.currentGlobalFrameIndex, 0)

        player.update(deltaTime: 0.1)
        XCTAssertEqual(player.currentGlobalFrameIndex, 1)

        player.update(deltaTime: 0.1)
        XCTAssertEqual(player.currentGlobalFrameIndex, 2)

        player.update(deltaTime: 0.1)
        XCTAssertEqual(player.currentGlobalFrameIndex, 0)
    }

    func testPlayerCanPlayTypedEnumAnimation() throws {
        let frame = AssistantFrame(
            index: 0,
            imageName: "frame_0000.png",
            sourceRect: IntRect(x: 0, y: 0, width: 10, height: 10),
            trimmedRect: IntRect(x: 0, y: 0, width: 10, height: 10),
            offset: IntPoint(x: 0, y: 0),
            size: IntSize(width: 10, height: 10),
            duration: 0.1
        )
        let frames = [frame]
        let manifest = AssistantManifest(
            characterName: "Clippy",
            frameCellSize: IntSize(width: 10, height: 10),
            frames: frames,
            animations: [AssistantAnimationClip(name: ClippyAnimation.greeting.rawValue, startFrame: 0, frameCount: 1, loops: true)]
        )

        let player = try AssistantFramePlayer(manifest: manifest)
        try player.play(ClippyAnimation.greeting)
        XCTAssertEqual(player.currentAnimationName, ClippyAnimation.greeting.rawValue)
        XCTAssertEqual(player.currentGlobalFrameIndex, 0)
    }

    func testPlayerCanPlayOnce() throws {
        let frames = (0..<2).map { index in
            AssistantFrame(
                index: index,
                imageName: "frame_\(index).png",
                sourceRect: IntRect(x: 0, y: 0, width: 10, height: 10),
                trimmedRect: IntRect(x: 0, y: 0, width: 10, height: 10),
                offset: IntPoint(x: 0, y: 0),
                size: IntSize(width: 10, height: 10),
                duration: 0.1
            )
        }
        let manifest = AssistantManifest(
            characterName: "Clippy",
            frameCellSize: IntSize(width: 10, height: 10),
            frames: frames,
            animations: [AssistantAnimationClip(name: ClippyAnimation.greeting.rawValue, startFrame: 0, frameCount: 2, loops: true)]
        )

        let player = try AssistantFramePlayer(manifest: manifest)
        try player.play(ClippyAnimation.greeting)
        player.configurePlayback(looping: false, loopDelay: 0)
        player.update(deltaTime: 1.0)

        XCTAssertEqual(player.currentGlobalFrameIndex, 1)
    }

    func testPlayerLoopDelayPausesBeforeRestart() throws {
        let frames = (0..<2).map { index in
            AssistantFrame(
                index: index,
                imageName: "frame_\(index).png",
                sourceRect: IntRect(x: 0, y: 0, width: 10, height: 10),
                trimmedRect: IntRect(x: 0, y: 0, width: 10, height: 10),
                offset: IntPoint(x: 0, y: 0),
                size: IntSize(width: 10, height: 10),
                duration: 0.1
            )
        }
        let manifest = AssistantManifest(
            characterName: "Clippy",
            frameCellSize: IntSize(width: 10, height: 10),
            frames: frames,
            animations: [AssistantAnimationClip(name: ClippyAnimation.greeting.rawValue, startFrame: 0, frameCount: 2, loops: true)]
        )

        let player = try AssistantFramePlayer(manifest: manifest)
        try player.play(ClippyAnimation.greeting)
        player.configurePlayback(looping: true, loopDelay: 0.2)

        player.update(deltaTime: 0.2)
        XCTAssertEqual(player.currentGlobalFrameIndex, 1)

        player.update(deltaTime: 0.1)
        XCTAssertEqual(player.currentGlobalFrameIndex, 1)

        player.update(deltaTime: 0.19)
        XCTAssertEqual(player.currentGlobalFrameIndex, 0)

        player.update(deltaTime: 0.02)
        XCTAssertEqual(player.currentGlobalFrameIndex, 1)
    }

    func testEnumGeneratorCreatesStableSwiftIdentifiers() {
        let source = AnimationEnumGenerator.swiftEnumSource(
            typeName: "Clippy Animations",
            caseValues: ["Wave", "Wave", "1st Animation", "for", "Look-Left!"]
        )

        XCTAssertTrue(source.contains("enum ClippyAnimations"))
        XCTAssertTrue(source.contains("case wave = \"Wave\""))
        XCTAssertTrue(source.contains("case wave2 = \"Wave\""))
        XCTAssertTrue(source.contains("case n1stAnimation = \"1st Animation\""))
        XCTAssertTrue(source.contains("case forValue = \"for\""))
        XCTAssertTrue(source.contains("case lookLeft = \"Look-Left!\""))
    }

    func testPredefinedCharactersMatchBundledManifestAnimations() throws {
        for character in AssistantCharacter.allCases {
            let manifest = try character.loadManifest()
            XCTAssertFalse(manifest.frames.isEmpty)

            let manifestAnimationNames = manifest.animations
                .map(\.name)
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

            XCTAssertEqual(manifestAnimationNames, character.animationNames)
        }
    }

    func testAssistantAnimationHighLevelPlay() {
        let animation = AssistantAnimation()
        animation.play(ClippyAnimation.wave)
        XCTAssertEqual(animation.currentCharacter, .clippy)
        XCTAssertEqual(animation.currentAnimationName, ClippyAnimation.wave.rawValue)
        XCTAssertNil(animation.lastErrorDescription)
    }
}
