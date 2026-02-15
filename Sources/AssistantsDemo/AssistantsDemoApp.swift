import Assistants
import AppKit
import SwiftUI

private enum DemoAnimationOption: Hashable, Identifiable {
    case clippy(ClippyAnimation)
    case cat(CatAnimation)
    case rocky(RockyAnimation)

    var id: String {
        switch self {
        case let .clippy(animation):
            return "clippy:\(animation.rawValue)"
        case let .cat(animation):
            return "cat:\(animation.rawValue)"
        case let .rocky(animation):
            return "rocky:\(animation.rawValue)"
        }
    }

    var title: String {
        switch self {
        case let .clippy(animation):
            return animation.rawValue
        case let .cat(animation):
            return animation.rawValue
        case let .rocky(animation):
            return animation.rawValue
        }
    }

    static func options(for character: AssistantCharacter) -> [DemoAnimationOption] {
        switch character {
        case .clippy:
            ClippyAnimation.allCases
                .sorted { $0.rawValue.localizedCaseInsensitiveCompare($1.rawValue) == .orderedAscending }
                .map(Self.clippy)
        case .cat:
            CatAnimation.allCases
                .sorted { $0.rawValue.localizedCaseInsensitiveCompare($1.rawValue) == .orderedAscending }
                .map(Self.cat)
        case .rocky:
            RockyAnimation.allCases
                .sorted { $0.rawValue.localizedCaseInsensitiveCompare($1.rawValue) == .orderedAscending }
                .map(Self.rocky)
        }
    }
}

private final class DemoViewModel: ObservableObject {
    @Published var selectedCharacter: AssistantCharacter = .clippy
    @Published var selectedAnimation: DemoAnimationOption = .clippy(.greeting)
    @Published var isPlaying: Bool = true
    @Published var speed: Double = 1
    @Published var pixelScale: Double = 1
    @Published var playsOnce: Bool = false
    @Published var loopDelay: Double = 0

    let animation = AssistantAnimation()
    private var didStart = false

    var animationOptions: [DemoAnimationOption] {
        DemoAnimationOption.options(for: selectedCharacter)
    }

    init() {
        if let first = animationOptions.first {
            selectedAnimation = first
        }
    }

    func startIfNeeded() {
        guard !didStart else {
            return
        }
        didStart = true
        playSelectedAnimation()
    }

    func selectCharacter(_ character: AssistantCharacter) {
        guard selectedCharacter != character else {
            return
        }
        selectedCharacter = character
        if let first = animationOptions.first {
            selectedAnimation = first
        }
        playSelectedAnimation()
    }

    func selectAnimation(_ option: DemoAnimationOption) {
        guard selectedAnimation != option else {
            return
        }
        selectedAnimation = option
        playSelectedAnimation()
    }

    private func playSelectedAnimation() {
        switch selectedAnimation {
        case let .clippy(animationCase):
            animation.play(animationCase)
        case let .cat(animationCase):
            animation.play(animationCase)
        case let .rocky(animationCase):
            animation.play(animationCase)
        }
    }
}

private struct ContentView: View {
    @ObservedObject var viewModel: DemoViewModel
    private let windowWidth: CGFloat = 320
    private let rowLabelWidth: CGFloat = 84
    private let controlColumnWidth: CGFloat = 196

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let message = viewModel.animation.lastErrorDescription {
                Text(message)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(.red)
            }

            HStack(spacing: 8) {
                Text("Asset")
                    .frame(width: rowLabelWidth, alignment: .leading)
                Picker("Asset", selection: Binding(
                    get: { viewModel.selectedCharacter },
                    set: { viewModel.selectCharacter($0) }
                )) {
                    ForEach(AssistantCharacter.allCases, id: \.self) { character in
                        Text(character.displayName).tag(character)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: controlColumnWidth, alignment: .leading)
            }

            HStack(spacing: 8) {
                Text("Animation")
                    .frame(width: rowLabelWidth, alignment: .leading)
                Picker("Animation", selection: Binding(
                    get: { viewModel.selectedAnimation },
                    set: { viewModel.selectAnimation($0) }
                )) {
                    ForEach(viewModel.animationOptions) { option in
                        Text(option.title).tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: controlColumnWidth, alignment: .leading)
            }

            HStack(spacing: 8) {
                Text("Playback")
                    .frame(width: rowLabelWidth, alignment: .leading)
                HStack(spacing: 8) {
                    Button(viewModel.isPlaying ? "Pause" : "Play") {
                        viewModel.isPlaying.toggle()
                    }
                    Slider(value: $viewModel.speed, in: 0.25...4.0, step: 0.25)
                        .frame(width: 86)
                    Text(String(format: "%.2fx", viewModel.speed))
                        .frame(width: 44, alignment: .trailing)
                }
                .frame(width: controlColumnWidth, alignment: .leading)
            }

            HStack(spacing: 8) {
                Text("Pixel Scale")
                    .frame(width: rowLabelWidth, alignment: .leading)
                HStack(spacing: 8) {
                    Slider(value: $viewModel.pixelScale, in: 1...8, step: 1)
                        .frame(width: 144)
                    Text("\(Int(viewModel.pixelScale))x")
                        .frame(width: 44, alignment: .trailing)
                }
                .frame(width: controlColumnWidth, alignment: .leading)
            }

            HStack(spacing: 8) {
                Text("Play Once")
                    .frame(width: rowLabelWidth, alignment: .leading)
                Toggle("Once", isOn: $viewModel.playsOnce)
                    .labelsHidden()
                    .frame(width: controlColumnWidth, alignment: .leading)
            }

            HStack(spacing: 8) {
                Text("Loop Delay")
                    .frame(width: rowLabelWidth, alignment: .leading)
                HStack(spacing: 8) {
                    Slider(value: $viewModel.loopDelay, in: 0...2, step: 0.05)
                        .frame(width: 144)
                    Text(String(format: "%.2fs", viewModel.loopDelay))
                        .frame(width: 44, alignment: .trailing)
                }
                .frame(width: controlColumnWidth, alignment: .leading)
            }

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                AssistantAnimationPlayer(viewModel.animation)
                    .playbackSpeed(viewModel.speed)
                    .pixelScale(CGFloat(viewModel.pixelScale))
                    .playing(viewModel.isPlaying)
                    .playsOnce(viewModel.playsOnce)
                    .loopDelay(viewModel.loopDelay)
                    .checkerSize(8)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(width: windowWidth, alignment: .topLeading)
        .onAppear {
            viewModel.startIfNeeded()
        }
    }
}

private final class DemoAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
private struct AssistantsDemoApp: App {
    @NSApplicationDelegateAdaptor(DemoAppDelegate.self) private var appDelegate
    @StateObject private var viewModel = DemoViewModel()

    var body: some Scene {
        WindowGroup("Assistants Demo") {
            ContentView(viewModel: viewModel)
        }
        .defaultSize(width: 320, height: 500)
        .windowResizability(.contentSize)
    }
}
