//
//  MarkdownText.swift
//  AssistanceKit
//
//  Inline Markdown text renderer.
//  Generalised from toogether for cross-project reuse.
//

#if canImport(SwiftUI)
import SwiftUI

/// Renders a plain `String` as inline Markdown using `AttributedString`.
///
/// Supports **bold**, *italic*, `code`, ~~strikethrough~~, and
/// [links](https://example.com). Falls back to plain `Text` when the
/// string contains no valid Markdown or parsing fails.
///
/// Usage:
/// ```swift
/// MarkdownText("**Bold** and *italic* with a [link](https://example.com)")
/// ```
///
/// - Note: This uses the built-in `AttributedString(markdown:)` which
///   supports inline Markdown only (no block-level elements like headings or
///   lists). Use ``MarkdownDocumentView`` for full block rendering.
public struct MarkdownText: View {
    private let content: AttributedString

    /// Creates a Markdown-rendered text view.
    ///
    /// - Parameter markdown: Raw Markdown string to render. If parsing fails,
    ///   the original string is displayed as plain text.
    public init(_ markdown: String) {
        if let attributed = try? AttributedString(
            markdown: markdown,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            self.content = attributed
        } else {
            self.content = AttributedString(markdown)
        }
    }

    /// The `View` body that renders the Markdown content as styled `Text`.
    public var body: some View {
        Text(content)
    }
}

#Preview("Markdown formatting") {
    VStack(alignment: .leading, spacing: 12) {
        MarkdownText("Plain text without any formatting")
        MarkdownText("**Bold** and *italic* text")
        MarkdownText("Some `inline code` here")
        MarkdownText("~~Strikethrough~~ text")
        MarkdownText("A [link](https://example.com) in text")
        MarkdownText("Mixed: **bold**, *italic*, `code`, and [link](https://example.com)")
        MarkdownText("") // Empty string
    }
    .padding()
}

#endif
