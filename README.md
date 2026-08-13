# markdown-ui

Lightweight Markdown rendering & editing components for SwiftUI/AppKit,
extracted from `wichtelimwald/assistance` (previously part of the
`AssistanceKit` umbrella in `shared-ui/`).

> Spun off in 2026. See
> [`docs/decisions/ADR-0010-spinoff-from-monorepo.md`](docs/decisions/ADR-0010-spinoff-from-monorepo.md).

## Requirements

- Swift 5.9+ · macOS 14+ · iOS 17+ · Xcode 15+
- Zero external dependencies.

## Usage

```swift
.package(
    url: "https://github.com/wichtelimwald/markdown-ui.git",
    .upToNextMajor(from: "0.1.0")
)
```

```swift
import MarkdownUI
```

## Build & Test

```bash
swift build
swift test
```

## Sibling packages

| Package        | Repo                                           |
|----------------|------------------------------------------------|
| `CoverFlow`    | https://github.com/wichtelimwald/coverflow     |
| `GlassOverlay` | https://github.com/wichtelimwald/glass-overlay |
| `MarkdownUI`   | https://github.com/wichtelimwald/markdown-ui   |
| `SharedUI`     | https://github.com/wichtelimwald/shared-ui     |
