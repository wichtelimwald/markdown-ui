# ADR-0010: Spin-off from the `wichtelimwald/assistance` mono-repo

**Status:** Accepted
**Date:** 2026-05-20
**Related:** ADR-0012 in `wichtelimwald/assistance` (mono-repo split strategy)

## Context

`MarkdownUI` was previously one module of the `AssistanceKit` umbrella SwiftPM
package in `wichtelimwald/assistance:shared-ui/`. With ~10 source files it
was the largest module by far in the umbrella, but it shared the same release
line as six unrelated UI components.

## Decision

Split the `AssistanceKit` umbrella into four standalone SwiftPM packages.
`Markdown` becomes its own repository `wichtelimwald/markdown-ui`, with the
SwiftPM product renamed to `MarkdownUI` to disambiguate it from Apple's own
`MarkdownUI`-style libraries in the ecosystem.

Sibling packages:

- `wichtelimwald/coverflow` (product `CoverFlow`, no deps)
- `wichtelimwald/glass-overlay` (product `GlassOverlay`, depends on `SharedUI`)
- `wichtelimwald/markdown-ui` (this repo, product `MarkdownUI`, no deps)
- `wichtelimwald/shared-ui` (product `SharedUI`: Backgrounds/Buttons/Compatibility/Styles)

## Consequences

**Positive**
- Independent versioning.
- Public-API contract surfaced at package boundary.
- Smaller blast radius for breaking changes.

**Negative**
- Consumers using both Markdown and other former-umbrella modules need
  multiple SPM entries + `import` lines.

## Implementation notes

- The migration script (`scripts/migrate-markdown-ui/migrate.sh` in the
  mono-repo) copies `shared-ui/Sources/AssistanceKit/Markdown/` plus the
  10 `Markdown*Tests.swift` files and `ContentProvenanceTests.swift`.
- No Git history preserved.
- Mono-repo cleanup is a separate PR.
