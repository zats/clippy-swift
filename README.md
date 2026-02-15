# ClippySwift

![](preview.gif)

Prebuilt Office Assistant animations (Clippy, Cat, Rocky) for Swift apps.


## Example

```swift
import ClippySwift
import SwiftUI

struct DemoView: View {
    @State private var assistant = AssistantAnimation()

    var body: some View {
        AssistantAnimationPlayer(assistant)
            .onAppear {
                assistant.play(ClippyAnimation.wave)
            }
    }
}
```

## More Advanced Examples

### Playback config (speed, once, loop delay)

```swift
AssistantAnimationPlayer(assistant)
    .playbackSpeed(1.5)
    .pixelScale(3)
    .playsOnce(true)
    .loopDelay(0.25)
```

### Switch characters/animations at runtime

```swift
assistant.play(ClippyAnimation.greeting)
assistant.play(CatAnimation.thinking)
assistant.play(RockyAnimation.getAttention)
```

## Installation

SPM repo URL:

`https://github.com/zats/clippy-swift`

```swift
.package(url: "https://github.com/zats/clippy-swift", from: "0.1.0")
```

Then depend on product `ClippySwift`.
