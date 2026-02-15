import Foundation

#if canImport(CoreGraphics) && canImport(ImageIO)
import CoreGraphics
import ImageIO
#endif

public struct AcsIngestOptions: Sendable {
    public let characterName: String?
    public let fallbackFrameDuration: TimeInterval
    public let outputDirectory: URL
    public let outputPrefix: String

    public init(
        characterName: String? = nil,
        fallbackFrameDuration: TimeInterval = 1.0 / 12.0,
        outputDirectory: URL,
        outputPrefix: String = "frame"
    ) {
        self.characterName = characterName
        self.fallbackFrameDuration = fallbackFrameDuration
        self.outputDirectory = outputDirectory
        self.outputPrefix = outputPrefix
    }
}

public struct AcsIngestResult: Sendable {
    public let manifestURL: URL
    public let framesDirectory: URL
    public let manifest: AssistantManifest

    public init(manifestURL: URL, framesDirectory: URL, manifest: AssistantManifest) {
        self.manifestURL = manifestURL
        self.framesDirectory = framesDirectory
        self.manifest = manifest
    }
}

public enum AcsIngestor {
    public static func ingest(from acsURL: URL, options: AcsIngestOptions) throws -> AcsIngestResult {
        #if canImport(CoreGraphics) && canImport(ImageIO)
        let data: Data
        do {
            data = try Data(contentsOf: acsURL)
        } catch {
            throw ClippySwiftError.ioFailed("Unable to read ACS file at \(acsURL.path): \(error.localizedDescription)")
        }

        let parsed = try AcsParser.parse(data: data)

        let fileManager = FileManager.default
        try fileManager.createDirectory(at: options.outputDirectory, withIntermediateDirectories: true)
        let framesDirectory = options.outputDirectory

        let characterName = options.characterName ?? acsURL.deletingPathExtension().lastPathComponent
        var frames: [AssistantFrame] = []
        frames.reserveCapacity(parsed.animations.reduce(0) { $0 + $1.frames.count })
        var animations: [AssistantAnimationClip] = []
        animations.reserveCapacity(parsed.animations.count)

        let frameCanvas = parsed.canvasSize
        let totalFrameCount = parsed.animations.reduce(0) { $0 + $1.frames.count }
        guard totalFrameCount > 0 else {
            throw ClippySwiftError.emptyFrames
        }
        let atlasLayout = try makeAtlasLayout(
            totalFrames: totalFrameCount,
            frameSize: frameCanvas,
            maxDimension: 16_384
        )
        var atlasRGBA = [UInt8](repeating: 0, count: atlasLayout.width * atlasLayout.height * 4)

        var frameCursor = 0

        for animation in parsed.animations {
            let animationStart = frameCursor

            for frame in animation.frames {
                let rgba = compositeFrame(
                    frame: frame,
                    images: parsed.images,
                    palette: parsed.palette,
                    transparencyIndex: parsed.transparencyIndex,
                    canvas: frameCanvas
                )
                let atlasPosition = atlasLayout.position(for: frameCursor)
                blitFrame(
                    rgba: rgba,
                    frameSize: frameCanvas,
                    into: &atlasRGBA,
                    atlasWidth: atlasLayout.width,
                    at: atlasPosition
                )

                let duration: TimeInterval
                if frame.durationTicks > 0 {
                    duration = max(Double(frame.durationTicks) / 100.0, 1.0 / 120.0)
                } else {
                    duration = options.fallbackFrameDuration
                }

                frames.append(
                    AssistantFrame(
                        index: frameCursor,
                        imageName: "atlas.png",
                        sourceRect: IntRect(
                            x: atlasPosition.x,
                            y: atlasPosition.y,
                            width: frameCanvas.width,
                            height: frameCanvas.height
                        ),
                        trimmedRect: IntRect(x: 0, y: 0, width: frameCanvas.width, height: frameCanvas.height),
                        offset: IntPoint(x: 0, y: 0),
                        size: frameCanvas,
                        duration: duration
                    )
                )
                frameCursor += 1
            }

            let count = frameCursor - animationStart
            guard count > 0 else {
                continue
            }
            animations.append(
                AssistantAnimationClip(
                    name: animation.name,
                    startFrame: animationStart,
                    frameCount: count,
                    loops: true
                )
            )
        }

        if animations.isEmpty {
            animations = [AssistantAnimationClip(name: "all", startFrame: 0, frameCount: frames.count, loops: true)]
        }

        let atlasURL = options.outputDirectory.appendingPathComponent("atlas.png")
        try writePNG(rgba: atlasRGBA, width: atlasLayout.width, height: atlasLayout.height, to: atlasURL)

        let manifest = AssistantManifest(
            characterName: characterName,
            frameCellSize: frameCanvas,
            frames: frames,
            animations: uniqueAnimationNames(animations)
        )
        let manifestURL = options.outputDirectory.appendingPathComponent("manifest.json")
        try AssistantManifestIO.save(manifest, to: manifestURL)
        return AcsIngestResult(manifestURL: manifestURL, framesDirectory: framesDirectory, manifest: manifest)
        #else
        throw ClippySwiftError.unsupportedPlatform("ACS ingest requires CoreGraphics and ImageIO.")
        #endif
    }
}

private let acsSignature: UInt32 = 0xABCDABC3
private let styleHasTTS: UInt32 = 0x00000020
private let styleHasBalloon: UInt32 = 0x00000200

private struct BlockDef {
    let offset: Int
    let size: Int
}

private struct ParsedAcs {
    let canvasSize: IntSize
    let transparencyIndex: UInt8
    let palette: [UInt32]
    let images: [IndexedImage]
    let animations: [ParsedAnimation]
}

private struct ParsedAnimation {
    let name: String
    let frames: [ParsedFrame]
}

private struct ParsedFrame {
    let durationTicks: UInt16
    let layers: [FrameLayer]
}

private struct FrameLayer {
    let imageIndex: Int
    let offset: IntPoint
}

private struct IndexedImage {
    let width: Int
    let height: Int
    let stride: Int
    let pixels: [UInt8]
}

private struct AtlasLayout {
    let columns: Int
    let rows: Int
    let width: Int
    let height: Int
    let frameSize: IntSize

    func position(for frameIndex: Int) -> IntPoint {
        let column = frameIndex % columns
        let row = frameIndex / columns
        return IntPoint(x: column * frameSize.width, y: row * frameSize.height)
    }
}

private enum AcsParser {
    static func parse(data: Data) throws -> ParsedAcs {
        var reader = DataReader(data: data)
        let signature = try reader.readUInt32()
        guard signature == acsSignature else {
            throw ClippySwiftError.invalidInput(
                "Unsupported ACS signature 0x\(String(signature, radix: 16, uppercase: true)). " +
                    "Only Agent 2.0 ACS (0xABCDABC3) is currently supported."
            )
        }

        var blocks: [BlockDef] = []
        blocks.reserveCapacity(4)
        for _ in 0..<4 {
            let offset = Int(try reader.readUInt32())
            let size = Int(try reader.readUInt32())
            blocks.append(BlockDef(offset: offset, size: size))
        }
        guard blocks.count == 4 else {
            throw ClippySwiftError.decodeFailed("Invalid ACS block definition table.")
        }

        let header = try parseHeader(data: data, block: blocks[0])
        let gestureRefs = try parseGestureRefs(data: data, block: blocks[1])
        let imageRefs = try parseImageRefs(data: data, block: blocks[2])

        let images = try imageRefs.enumerated().map { index, ref in
            do {
                return try parseImage(data: data, offset: ref.offset, size: ref.size, imageIndex: index)
            } catch {
                throw ClippySwiftError.decodeFailed("Failed to decode ACS image #\(index): \(error.localizedDescription)")
            }
        }

        let animations = try gestureRefs.map { ref in
            let parsed = try parseAnimation(data: data, offset: ref.offset, size: ref.size)
            let name = ref.name.isEmpty ? parsed.name : ref.name
            return ParsedAnimation(name: name, frames: parsed.frames)
        }

        return ParsedAcs(
            canvasSize: header.canvasSize,
            transparencyIndex: header.transparencyIndex,
            palette: header.palette,
            images: images,
            animations: animations
        )
    }
}

private struct HeaderInfo {
    let canvasSize: IntSize
    let transparencyIndex: UInt8
    let palette: [UInt32]
}

private struct GestureRef {
    let name: String
    let offset: Int
    let size: Int
}

private struct AssetRef {
    let offset: Int
    let size: Int
}

private func parseHeader(data: Data, block: BlockDef) throws -> HeaderInfo {
    var reader = try DataReader(data: data, rangeOffset: block.offset, rangeLength: block.size)

    _ = try reader.readUInt16() // minor
    _ = try reader.readUInt16() // major
    _ = try reader.readUInt32() // names absolute offset
    _ = try reader.readUInt32() // names byte size
    _ = try reader.skip(count: 16) // guid

    let width = Int(try reader.readUInt16())
    let height = Int(try reader.readUInt16())
    let transparency = try reader.readUInt8()
    let style = try reader.readUInt32()
    _ = try reader.readUInt32() // unknown, usually 0x2

    if style & styleHasTTS != 0 {
        try skipTTS(reader: &reader)
    }
    if style & styleHasBalloon != 0 {
        try skipBalloon(reader: &reader)
    }

    let paletteCount = Int(try reader.readUInt32())
    var palette = [UInt32](repeating: 0, count: 256)
    for index in 0..<paletteCount {
        let value = try reader.readUInt32()
        if index < 256 {
            palette[index] = value
        }
    }

    let hasIcon = try reader.readUInt8()
    if hasIcon != 0 {
        let maskSize = Int(try reader.readUInt32())
        _ = try reader.skip(count: maskSize)
        let colorSize = Int(try reader.readUInt32())
        _ = try reader.skip(count: colorSize)
    }

    return HeaderInfo(
        canvasSize: IntSize(width: width, height: height),
        transparencyIndex: transparency,
        palette: palette
    )
}

private func skipTTS(reader: inout DataReader) throws {
    _ = try reader.skip(count: 16) // engine guid
    _ = try reader.skip(count: 16) // mode guid
    _ = try reader.skip(count: 4) // speed
    _ = try reader.skip(count: 2) // pitch

    let hasLanguage = try reader.readUInt8()
    guard hasLanguage != 0 else {
        return
    }

    _ = try reader.skip(count: 2) // language
    let unknownStringLength = Int(try reader.readUInt32())
    _ = try reader.skip(count: (unknownStringLength + 1) * 2)
    _ = try reader.skip(count: 2) // gender
    _ = try reader.skip(count: 2) // age
    let styleLength = Int(try reader.readUInt32())
    _ = try reader.skip(count: (styleLength + 1) * 2)
}

private func skipBalloon(reader: inout DataReader) throws {
    _ = try reader.skip(count: 1) // lines
    _ = try reader.skip(count: 1) // chars per line
    _ = try reader.skip(count: 4) // fg
    _ = try reader.skip(count: 4) // bg
    _ = try reader.skip(count: 4) // border

    let fontNameLength = Int(try reader.readUInt32())
    _ = try reader.skip(count: (fontNameLength + 1) * 2)
    _ = try reader.skip(count: 4) // font height
    _ = try reader.skip(count: 2) // font weight
    _ = try reader.skip(count: 2) // strike-through + padding
    _ = try reader.skip(count: 2) // italic + padding
}

private func parseGestureRefs(data: Data, block: BlockDef) throws -> [GestureRef] {
    var reader = try DataReader(data: data, rangeOffset: block.offset, rangeLength: block.size)
    let count = Int(try reader.readUInt32())
    var refs: [GestureRef] = []
    refs.reserveCapacity(count)

    for _ in 0..<count {
        let nameLength = Int(try reader.readUInt32())
        let name = try reader.readUTF16String(length: nameLength)
        _ = try reader.skip(count: 2) // null terminator

        let offset = Int(try reader.readUInt32())
        let size = Int(try reader.readUInt32())
        refs.append(GestureRef(name: name, offset: offset, size: size))
    }
    return refs
}

private func parseImageRefs(data: Data, block: BlockDef) throws -> [AssetRef] {
    var reader = try DataReader(data: data, rangeOffset: block.offset, rangeLength: block.size)
    let count = Int(try reader.readUInt32())
    var refs: [AssetRef] = []
    refs.reserveCapacity(count)

    for _ in 0..<count {
        let offset = Int(try reader.readUInt32())
        let size = Int(try reader.readUInt32())
        _ = try reader.readUInt32() // checksum
        refs.append(AssetRef(offset: offset, size: size))
    }
    return refs
}

private func parseAnimation(data: Data, offset: Int, size: Int) throws -> ParsedAnimation {
    var reader = try DataReader(data: data, rangeOffset: offset, rangeLength: size)

    let nameLength = Int(try reader.readUInt32())
    let animationName = try reader.readUTF16String(length: nameLength)
    _ = try reader.skip(count: 2) // null terminator

    _ = try reader.readUInt8() // return type
    let returnNameLength = Int(try reader.readUInt32())
    if returnNameLength > 0 {
        _ = try reader.readUTF16String(length: returnNameLength)
        _ = try reader.skip(count: 2)
    }

    let frameCount = Int(try reader.readUInt16())
    var frames: [ParsedFrame] = []
    frames.reserveCapacity(frameCount)

    for _ in 0..<frameCount {
        let imageCount = Int(try reader.readUInt16())
        var layers: [FrameLayer] = []
        layers.reserveCapacity(imageCount)

        for _ in 0..<imageCount {
            let imageIndex = Int(try reader.readUInt32())
            let x = Int(try reader.readInt16())
            let y = Int(try reader.readInt16())
            layers.append(FrameLayer(imageIndex: imageIndex, offset: IntPoint(x: x, y: y)))
        }

        _ = try reader.readUInt16() // sound
        let duration = try reader.readUInt16()
        _ = try reader.readUInt16() // exit frame

        let branchCount = Int(try reader.readUInt8())
        if branchCount > 0 {
            _ = try reader.skip(count: branchCount * 4)
        }

        let overlayCount = Int(try reader.readUInt8())
        if overlayCount > 0 {
            for _ in 0..<overlayCount {
                _ = try reader.readUInt8() // overlay index
                _ = try reader.readUInt8() // replace flag
                let imageIndex = Int(try reader.readUInt16())
                _ = try reader.readUInt8() // unknown
                _ = try reader.readUInt8() // region flag
                let x = Int(try reader.readInt16())
                let y = Int(try reader.readInt16())
                _ = try reader.readInt16() // something x
                _ = try reader.readInt16() // something y
                layers.append(FrameLayer(imageIndex: imageIndex, offset: IntPoint(x: x, y: y)))
            }
        }

        frames.append(ParsedFrame(durationTicks: duration, layers: layers))
    }

    return ParsedAnimation(name: animationName, frames: frames)
}

private func parseImage(data: Data, offset: Int, size: Int, imageIndex: Int) throws -> IndexedImage {
    var reader = try DataReader(data: data, rangeOffset: offset, rangeLength: size)
    _ = try reader.readUInt8() // first byte
    let width = Int(try reader.readUInt16())
    let height = Int(try reader.readUInt16())
    let compressed = try reader.readUInt8() != 0
    let byteCount = Int(try reader.readUInt32())
    let payload = try reader.readBytes(count: byteCount)

    guard width > 0, height > 0 else {
        throw ClippySwiftError.decodeFailed("Image #\(imageIndex) has invalid dimensions \(width)x\(height).")
    }

    let stride = ((width + 3) / 4) * 4
    let pixelCount = stride * height
    let pixels: [UInt8]

    if compressed {
        guard let decoded = decodeAcsData(payload, targetSize: pixelCount) else {
            throw ClippySwiftError.decodeFailed("Image #\(imageIndex) compressed payload failed to decode.")
        }
        pixels = decoded
    } else {
        guard payload.count >= pixelCount else {
            throw ClippySwiftError.decodeFailed(
                "Image #\(imageIndex) payload is truncated: expected \(pixelCount), got \(payload.count)."
            )
        }
        pixels = Array(payload.prefix(pixelCount))
    }

    return IndexedImage(width: width, height: height, stride: stride, pixels: pixels)
}

private func compositeFrame(
    frame: ParsedFrame,
    images: [IndexedImage],
    palette: [UInt32],
    transparencyIndex: UInt8,
    canvas: IntSize
) -> [UInt8] {
    var rgba = [UInt8](repeating: 0, count: canvas.width * canvas.height * 4)
    guard canvas.width > 0, canvas.height > 0 else {
        return rgba
    }

    for layer in frame.layers {
        guard layer.imageIndex >= 0, layer.imageIndex < images.count else {
            continue
        }
        let image = images[layer.imageIndex]
        for sy in 0..<image.height {
            let dy = layer.offset.y + sy
            guard dy >= 0, dy < canvas.height else {
                continue
            }
            // ACS image payload rows are stored bottom-up (DIB style).
            let sourceRow = (image.height - 1 - sy) * image.stride
            let targetRow = dy * canvas.width
            for sx in 0..<image.width {
                let dx = layer.offset.x + sx
                guard dx >= 0, dx < canvas.width else {
                    continue
                }
                let paletteIndex = image.pixels[sourceRow + sx]
                if paletteIndex == transparencyIndex {
                    continue
                }
                let color = palette[Int(paletteIndex)]
                let targetPixel = (targetRow + dx) * 4
                rgba[targetPixel] = UInt8((color >> 16) & 0xFF) // R
                rgba[targetPixel + 1] = UInt8((color >> 8) & 0xFF) // G
                rgba[targetPixel + 2] = UInt8(color & 0xFF) // B
                rgba[targetPixel + 3] = 255
            }
        }
    }

    return rgba
}

private func makeAtlasLayout(totalFrames: Int, frameSize: IntSize, maxDimension: Int) throws -> AtlasLayout {
    guard frameSize.width > 0, frameSize.height > 0 else {
        throw ClippySwiftError.invalidInput("Invalid frame canvas \(frameSize.width)x\(frameSize.height).")
    }

    let maxColumns = max(1, maxDimension / frameSize.width)
    let preferredColumns = max(1, Int(ceil(sqrt(Double(totalFrames)))))
    let columns = min(maxColumns, preferredColumns)
    let rows = (totalFrames + columns - 1) / columns
    let atlasWidth = columns * frameSize.width
    let atlasHeight = rows * frameSize.height
    guard atlasWidth <= maxDimension, atlasHeight <= maxDimension else {
        throw ClippySwiftError.invalidInput(
            "Atlas dimensions exceed \(maxDimension)x\(maxDimension). Reduce frame count or split assets."
        )
    }

    return AtlasLayout(
        columns: columns,
        rows: rows,
        width: atlasWidth,
        height: atlasHeight,
        frameSize: frameSize
    )
}

private func blitFrame(
    rgba: [UInt8],
    frameSize: IntSize,
    into atlas: inout [UInt8],
    atlasWidth: Int,
    at position: IntPoint
) {
    let frameBytesPerRow = frameSize.width * 4
    let atlasBytesPerRow = atlasWidth * 4
    for row in 0..<frameSize.height {
        let sourceStart = row * frameBytesPerRow
        let sourceEnd = sourceStart + frameBytesPerRow
        let destinationStart = ((position.y + row) * atlasBytesPerRow) + (position.x * 4)
        let destinationEnd = destinationStart + frameBytesPerRow
        atlas[destinationStart..<destinationEnd] = rgba[sourceStart..<sourceEnd]
    }
}

private func uniqueAnimationNames(_ animations: [AssistantAnimationClip]) -> [AssistantAnimationClip] {
    var seen: [String: Int] = [:]
    var result: [AssistantAnimationClip] = []
    result.reserveCapacity(animations.count)

    for animation in animations {
        let key = animation.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = key.isEmpty ? "animation" : key
        let suffix = seen[base, default: 0]
        seen[base] = suffix + 1
        let uniqueName = suffix == 0 ? base : "\(base)_\(suffix)"
        result.append(
            AssistantAnimationClip(
                name: uniqueName,
                startFrame: animation.startFrame,
                frameCount: animation.frameCount,
                loops: animation.loops
            )
        )
    }
    return result
}

#if canImport(CoreGraphics) && canImport(ImageIO)
private func writePNG(rgba: [UInt8], width: Int, height: Int, to url: URL) throws {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bytesPerRow = width * 4
    let data = Data(rgba)
    guard let provider = CGDataProvider(data: data as CFData) else {
        throw ClippySwiftError.encodeFailed("Unable to allocate image data provider.")
    }

    let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(.init(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue))
    guard let image = CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: bitmapInfo,
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    ) else {
        throw ClippySwiftError.encodeFailed("Unable to create CGImage.")
    }

    let pngType = "public.png" as CFString
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, pngType, 1, nil) else {
        throw ClippySwiftError.encodeFailed("Unable to create PNG destination at \(url.path).")
    }
    CGImageDestinationAddImage(destination, image, nil)
    if !CGImageDestinationFinalize(destination) {
        throw ClippySwiftError.encodeFailed("Unable to finalize PNG at \(url.path).")
    }
}
#endif

private func decodeAcsData(_ source: [UInt8], targetSize: Int) -> [UInt8]? {
    guard source.count > 7 else {
        return nil
    }
    guard source[0] == 0 else {
        return nil
    }

    var trailerMatchCount = 1
    while trailerMatchCount <= 6 {
        let index = source.count - trailerMatchCount
        if source[index] == 0xFF {
            trailerMatchCount += 1
        } else {
            break
        }
    }
    guard trailerMatchCount >= 6 else {
        return nil
    }

    var srcPointer = 5
    var bitCount = 0
    var target = [UInt8](repeating: 0, count: targetSize)
    var targetPointer = 0

    while srcPointer < source.count && targetPointer < targetSize {
        guard let srcQuad = readUInt32LE(source, at: srcPointer - 4) else {
            return nil
        }
        var quad = srcQuad

        if bit(quad, at: bitCount) {
            var sourceOffsetFlag = 1
            var distance: UInt32

            if bit(quad, at: bitCount + 1) {
                if bit(quad, at: bitCount + 2) {
                    if bit(quad, at: bitCount + 3) {
                        let shift = bitCount + 4
                        guard shift < 32 else { return nil }
                        distance = (quad >> UInt32(shift)) & 0x000F_FFFF
                        if distance == 0x000F_FFFF {
                            break
                        }
                        distance += 4673
                        bitCount += 24
                        sourceOffsetFlag = 2
                    } else {
                        let shift = bitCount + 4
                        guard shift < 32 else { return nil }
                        distance = ((quad >> UInt32(shift)) & 0x0000_0FFF) + 577
                        bitCount += 16
                    }
                } else {
                    let shift = bitCount + 3
                    guard shift < 32 else { return nil }
                    distance = ((quad >> UInt32(shift)) & 0x0000_01FF) + 65
                    bitCount += 12
                }
            } else {
                let shift = bitCount + 2
                guard shift < 32 else { return nil }
                distance = ((quad >> UInt32(shift)) & 0x0000_003F) + 1
                bitCount += 8
            }

            srcPointer += bitCount / 8
            bitCount &= 7

            guard let runQuad = readUInt32LE(source, at: srcPointer - 4) else {
                return nil
            }
            var runCount = 0
            while bit(runQuad, at: bitCount + runCount) {
                runCount += 1
                if runCount > 11 {
                    break
                }
            }

            let runShift = bitCount + runCount + 1
            guard runShift < 32 else {
                return nil
            }

            var runLength = runQuad >> UInt32(runShift)
            let mask: UInt32 = runCount == 0 ? 0 : (UInt32(1) << UInt32(runCount)) - 1
            runLength &= mask
            runLength += UInt32(1) << UInt32(runCount)
            runLength += UInt32(sourceOffsetFlag)
            bitCount += runCount * 2 + 1

            let distanceInt = Int(distance)
            let runLengthInt = Int(runLength)
            if targetPointer + runLengthInt > targetSize {
                break
            }
            if targetPointer - distanceInt < 0 {
                break
            }
            for _ in 0..<runLengthInt {
                target[targetPointer] = target[targetPointer - distanceInt]
                targetPointer += 1
            }
        } else {
            let shift = bitCount + 1
            guard shift < 32 else {
                return nil
            }
            quad >>= UInt32(shift)
            bitCount += 9
            target[targetPointer] = UInt8(quad & 0xFF)
            targetPointer += 1
        }

        srcPointer += bitCount / 8
        bitCount &= 7
    }

    guard targetPointer == targetSize else {
        return nil
    }
    return target
}

@inline(__always)
private func bit(_ value: UInt32, at index: Int) -> Bool {
    guard index >= 0 && index < 32 else {
        return false
    }
    return (value & (UInt32(1) << UInt32(index))) != 0
}

@inline(__always)
private func readUInt32LE(_ bytes: [UInt8], at index: Int) -> UInt32? {
    guard index >= 0, index + 3 < bytes.count else {
        return nil
    }
    return UInt32(bytes[index]) |
        (UInt32(bytes[index + 1]) << 8) |
        (UInt32(bytes[index + 2]) << 16) |
        (UInt32(bytes[index + 3]) << 24)
}

private struct DataReader {
    let data: Data
    let start: Int
    let end: Int
    var offset: Int

    init(data: Data) {
        self.data = data
        self.start = 0
        self.end = data.count
        self.offset = 0
    }

    init(data: Data, rangeOffset: Int, rangeLength: Int) throws {
        guard rangeOffset >= 0, rangeLength >= 0, rangeOffset + rangeLength <= data.count else {
            throw ClippySwiftError.decodeFailed("Invalid data range offset \(rangeOffset), length \(rangeLength).")
        }
        self.data = data
        self.start = rangeOffset
        self.end = rangeOffset + rangeLength
        self.offset = rangeOffset
    }

    mutating func readUInt8() throws -> UInt8 {
        let range = try take(count: 1)
        return data[range.lowerBound]
    }

    mutating func readUInt16() throws -> UInt16 {
        let range = try take(count: 2)
        let b0 = UInt16(data[range.lowerBound])
        let b1 = UInt16(data[range.lowerBound + 1]) << 8
        return b0 | b1
    }

    mutating func readInt16() throws -> Int16 {
        Int16(bitPattern: try readUInt16())
    }

    mutating func readUInt32() throws -> UInt32 {
        let range = try take(count: 4)
        let b0 = UInt32(data[range.lowerBound])
        let b1 = UInt32(data[range.lowerBound + 1]) << 8
        let b2 = UInt32(data[range.lowerBound + 2]) << 16
        let b3 = UInt32(data[range.lowerBound + 3]) << 24
        return b0 | b1 | b2 | b3
    }

    mutating func readBytes(count: Int) throws -> [UInt8] {
        let range = try take(count: count)
        return Array(data[range])
    }

    mutating func readUTF16String(length: Int) throws -> String {
        guard length >= 0 else {
            throw ClippySwiftError.decodeFailed("Negative UTF-16 string length \(length).")
        }
        let byteCount = length * 2
        let range = try take(count: byteCount)
        if length == 0 {
            return ""
        }
        var codeUnits: [UInt16] = []
        codeUnits.reserveCapacity(length)
        var cursor = range.lowerBound
        for _ in 0..<length {
            let unit = UInt16(data[cursor]) | (UInt16(data[cursor + 1]) << 8)
            codeUnits.append(unit)
            cursor += 2
        }
        return String(decoding: codeUnits, as: UTF16.self)
    }

    @discardableResult
    mutating func skip(count: Int) throws -> Int {
        _ = try take(count: count)
        return count
    }

    mutating func take(count: Int) throws -> Range<Int> {
        guard count >= 0 else {
            throw ClippySwiftError.decodeFailed("Negative read count \(count).")
        }
        guard offset + count <= end else {
            throw ClippySwiftError.decodeFailed(
                "Unexpected end of data while reading \(count) bytes at offset \(offset - start)."
            )
        }
        let range = offset..<(offset + count)
        offset += count
        return range
    }
}
