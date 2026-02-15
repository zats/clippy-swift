# assistants-swift

Prebuilt Office Assistant animations (Clippy, Cat, Rocky) for Swift apps.

You drive a single `AssistantAnimation` model and render it with `AssistantAnimationPlayer`.

## Example

```swift
import Assistants
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

`https://github.com/zats/assistants-swift`

```swift
.package(url: "https://github.com/zats/assistants-swift", from: "0.1.0")
```

Then depend on product `Assistants`.
