import AppKit
import ClippySwift
import SwiftUI

private enum DemoLayout {
    static let columnCount = 3
    static let rowCount = 3
    static let gridSpacing: CGFloat = 18
    static let gridPadding: CGFloat = 18
    static let topInset: CGFloat = 70
    static let tileSize = CGSize(width: 132, height: 101)
    static let windowSize = CGSize(
        width: (tileSize.width * CGFloat(columnCount)) + (gridSpacing * CGFloat(columnCount - 1)) + (gridPadding * 2),
        height: (tileSize.height * CGFloat(rowCount)) + (gridSpacing * CGFloat(rowCount - 1)) + (gridPadding * 2)
    )
}

private enum DemoClipID: Hashable, Identifiable {
    case clippy(ClippyAnimation)
    case cat(CatAnimation)
    case rocky(RockyAnimation)

    var id: Self { self }
}

private struct DemoClip: Identifiable {
    let id: DemoClipID
    let play: (AssistantAnimation) -> Void

    init(_ animation: ClippyAnimation) {
        id = .clippy(animation)
        play = { $0.play(animation) }
    }

    init(_ animation: CatAnimation) {
        id = .cat(animation)
        play = { $0.play(animation) }
    }

    init(_ animation: RockyAnimation) {
        id = .rocky(animation)
        play = { $0.play(animation) }
    }
}

private struct DemoTileView: View {
    let clip: DemoClip

    @State private var animation = AssistantAnimation()
    @State private var didStart = false

    var body: some View {
        AssistantAnimationPlayer(animation)
            .pixelScale(1)
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .center)
            .onAppear {
                guard !didStart else {
                    return
                }
                didStart = true
                clip.play(animation)
            }
    }
}

private struct ContentView: View {
    @State private var blissImage: NSImage?
    @State private var shuffledClips: [DemoClip] = Self.makeClips().shuffled()
    private static let trimHeight: CGFloat = 80

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.fixed(DemoLayout.tileSize.width), spacing: DemoLayout.gridSpacing),
            count: DemoLayout.columnCount
        )
    }

    private static func makeClips() -> [DemoClip] {
        [
            DemoClip(ClippyAnimation.wave),
            DemoClip(ClippyAnimation.greeting),
            DemoClip(ClippyAnimation.getAttention),
            DemoClip(CatAnimation.greeting),
            DemoClip(CatAnimation.idleButterFly),
            DemoClip(CatAnimation.wave),
            DemoClip(RockyAnimation.wave),
            DemoClip(RockyAnimation.getAttention),
            DemoClip(RockyAnimation.thinking)
        ]
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let blissImage {
                    Image(nsImage: blissImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height + Self.trimHeight)
                        .clipped()
                } else {
                    Color.black.opacity(0.08)
                }

                LazyVGrid(columns: columns, alignment: .center, spacing: DemoLayout.gridSpacing) {
                    ForEach(shuffledClips) { clip in
                        DemoTileView(clip: clip)
                            .frame(width: DemoLayout.tileSize.width, height: DemoLayout.tileSize.height)
                    }
                }
                .padding(.horizontal, DemoLayout.gridPadding)
                .padding(.bottom, DemoLayout.gridPadding)
                .padding(.top, DemoLayout.gridPadding + DemoLayout.topInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(width: DemoLayout.windowSize.width, height: DemoLayout.windowSize.height)
        .onAppear {
            if blissImage == nil {
                blissImage = Self.resolveBlissImage()
            }
        }
    }

    private static func resolveBlissImage() -> NSImage? {
        if let url = Bundle.module.url(forResource: "bliss", withExtension: "png"),
           let image = NSImage(contentsOf: url)
        {
            return image
        }
        if let url = Bundle.module.url(forResource: "bliss", withExtension: "png", subdirectory: "Resources"),
           let image = NSImage(contentsOf: url)
        {
            return image
        }
        return nil
    }
}

private final class DemoAppDelegate: NSObject, NSApplicationDelegate {
    private var windowObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        for window in NSApp.windows {
            Self.applyModernChrome(to: window)
        }

        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let window = notification.object as? NSWindow else {
                return
            }
            Self.applyModernChrome(to: window)
        }
    }

    func applicationWillTerminate(_: Notification) {
        if let windowObserver {
            NotificationCenter.default.removeObserver(windowObserver)
        }
    }

    private static func applyModernChrome(to window: NSWindow) {
        let toolbar = window.toolbar ?? NSToolbar(identifier: NSToolbar.Identifier("ClippySwiftDemoToolbar"))
        toolbar.showsBaselineSeparator = false
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        window.toolbar = toolbar

        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true
        if #available(macOS 11.0, *) {
            window.toolbarStyle = .unifiedCompact
        }
    }
}

@main
private struct ClippySwiftDemoApp: App {
    @NSApplicationDelegateAdaptor(DemoAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("ClippySwift Demo") {
            ContentView()
                .ignoresSafeArea(.all)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: DemoLayout.windowSize.width, height: DemoLayout.windowSize.height)
        .windowResizability(.contentSize)
    }
}
