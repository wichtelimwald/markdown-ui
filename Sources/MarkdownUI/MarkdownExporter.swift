//
//  MarkdownExporter.swift
//  AssistanceKit
//
//  Export pipeline: convert [MarkdownBlock] → HTML or NSAttributedString.
//  Pure Foundation logic for HTML; UIKit-gated for attributed strings.
//

import Foundation

// MARK: - MarkdownExporter

/// Converts parsed ``MarkdownBlock`` arrays into shareable formats.
///
/// ### Supported export formats
///
/// | Method | Output |
/// |--------|--------|
/// | ``html(from:title:)`` | Self-contained HTML string |
/// | ``attributedString(from:theme:)`` | Styled `NSAttributedString` (UIKit) |
///
/// ### Usage
///
/// ```swift
/// let blocks = MarkdownBlockParser.parse("# Hello\n\nWorld")
/// let html = MarkdownExporter.html(from: blocks)
/// ```
///
/// - SeeAlso: ``MarkdownBlockParser`` for parsing Markdown into blocks.
public enum MarkdownExporter {

    // MARK: - HTML Export

    /// Converts parsed Markdown blocks to an HTML string.
    ///
    /// Produces a self-contained HTML document with basic styling.
    /// Inline Markdown (bold, italic, code, links, strikethrough) is converted
    /// to the corresponding HTML elements.
    ///
    /// - Parameters:
    ///   - blocks: The parsed Markdown blocks to convert.
    ///   - title: Optional HTML `<title>` tag content. Defaults to `"Markdown Export"`.
    /// - Returns: A complete HTML document string.
    public static func html(from blocks: [MarkdownBlock], title: String = "Markdown Export") -> String {
        var lines: [String] = []
        lines.append("<!DOCTYPE html>")
        lines.append("<html lang=\"en\">")
        lines.append("<head>")
        lines.append("<meta charset=\"UTF-8\">")
        lines.append("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">")
        lines.append("<title>\(escapeHTML(title))</title>")
        lines.append("<style>")
        lines.append("body { font-family: -apple-system, system-ui, sans-serif; line-height: 1.6; max-width: 700px; margin: 0 auto; padding: 16px; }")
        lines.append("blockquote { border-left: 3px solid #ccc; margin: 8px 0; padding: 4px 12px; color: #666; }")
        lines.append("code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; font-size: 0.9em; }")
        lines.append("pre code { display: block; padding: 12px; overflow-x: auto; }")
        lines.append("img { max-width: 100%; height: auto; }")
        lines.append("hr { border: none; border-top: 1px solid #ddd; margin: 16px 0; }")
        lines.append("ul, ol { padding-left: 24px; }")
        lines.append(".task-item { list-style: none; }")
        lines.append(".tag { display: inline-block; background: #e8f0fe; color: #1a73e8; padding: 2px 8px; border-radius: 12px; font-size: 0.85em; margin: 2px; }")
        lines.append("</style>")
        lines.append("</head>")
        lines.append("<body>")

        for block in blocks {
            lines.append(htmlForBlock(block))
        }

        lines.append("</body>")
        lines.append("</html>")
        return lines.joined(separator: "\n")
    }

    /// Converts parsed Markdown blocks to an HTML fragment (no `<html>` wrapper).
    ///
    /// Useful when embedding the exported content inside an existing HTML document.
    ///
    /// - Parameter blocks: The parsed Markdown blocks to convert.
    /// - Returns: An HTML fragment string containing only `<body>` content.
    public static func htmlFragment(from blocks: [MarkdownBlock]) -> String {
        blocks.map { htmlForBlock($0) }.joined(separator: "\n")
    }

    // MARK: - Block → HTML

    private static func htmlForBlock(_ block: MarkdownBlock) -> String {
        switch block {
        case .h1(let text):
            return "<h1>\(inlineHTML(text))</h1>"
        case .h2(let text):
            return "<h2>\(inlineHTML(text))</h2>"
        case .h3(let text):
            return "<h3>\(inlineHTML(text))</h3>"
        case .paragraph(let text):
            return "<p>\(inlineHTML(text))</p>"
        case .listItem(let text, _):
            return "<ul><li>\(inlineHTML(text))</li></ul>"
        case .orderedListItem(let text, let number):
            return "<ol start=\"\(number)\"><li>\(inlineHTML(text))</li></ol>"
        case .taskListItem(let text, let isChecked):
            let checkbox = isChecked ? "☑" : "☐"
            let decoration = isChecked ? " style=\"text-decoration: line-through; color: #999;\"" : ""
            return "<ul class=\"task-item\"><li\(decoration)>\(checkbox) \(inlineHTML(text))</li></ul>"
        case .blockquote(let text):
            return "<blockquote>\(inlineHTML(text))</blockquote>"
        case .image(let alt, let url):
            return "<img src=\"\(escapeHTML(url))\" alt=\"\(escapeHTML(alt))\">"
        case .tagLine(let tags):
            let chips = tags.map { "<span class=\"tag\">#\(escapeHTML($0))</span>" }.joined(separator: " ")
            return "<p>\(chips)</p>"
        case .rule:
            return "<hr>"
        case .blank:
            return ""
        }
    }

    // MARK: - Inline Markdown → HTML

    /// Converts inline Markdown syntax to HTML elements.
    ///
    /// Handles: **bold**, *italic*, `code`, ~~strikethrough~~, [links](url), ![images](url).
    static func inlineHTML(_ text: String) -> String {
        var result = escapeHTML(text)

        // Bold: **text** or __text__
        result = result.replacingOccurrences(
            of: #"\*\*(.+?)\*\*"#,
            with: "<strong>$1</strong>",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"__(.+?)__"#,
            with: "<strong>$1</strong>",
            options: .regularExpression
        )

        // Italic: *text* or _text_ (but not inside ** or __)
        result = result.replacingOccurrences(
            of: #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#,
            with: "<em>$1</em>",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"(?<!_)_(?!_)(.+?)(?<!_)_(?!_)"#,
            with: "<em>$1</em>",
            options: .regularExpression
        )

        // Inline code: `code`
        result = result.replacingOccurrences(
            of: #"`(.+?)`"#,
            with: "<code>$1</code>",
            options: .regularExpression
        )

        // Strikethrough: ~~text~~
        result = result.replacingOccurrences(
            of: #"~~(.+?)~~"#,
            with: "<del>$1</del>",
            options: .regularExpression
        )

        // Links: [text](url)
        result = result.replacingOccurrences(
            of: #"\[(.+?)\]\((.+?)\)"#,
            with: "<a href=\"$2\">$1</a>",
            options: .regularExpression
        )

        return result
    }

    // MARK: - Helpers

    /// Escapes special HTML characters in a string.
    static func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

// MARK: - NSAttributedString Export

#if canImport(UIKit)
import UIKit

extension MarkdownExporter {

    /// Converts parsed Markdown blocks to a styled `NSAttributedString`.
    ///
    /// Uses the provided theme for heading colours, quote styling, and code
    /// background. Inline Markdown is rendered using `NSAttributedString(markdown:)`.
    ///
    /// - Parameters:
    ///   - blocks: The parsed Markdown blocks to convert.
    ///   - theme: The ``MarkdownTheme`` to use for styling. Defaults to ``MarkdownTheme/default``.
    ///   - colorScheme: Whether to use light or dark appearance. Defaults to `.light`.
    /// - Returns: A styled `NSAttributedString` suitable for display or clipboard.
    public static func attributedString(
        from blocks: [MarkdownBlock],
        theme: MarkdownTheme = .default,
        colorScheme: MarkdownTheme.ColorScheme = .light
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let appearance = theme.appearance(for: colorScheme)
        let accentColor = UIColor(markdownHex: appearance.accentColor) ?? .label
        let syntaxColor = UIColor(markdownHex: appearance.syntaxColor) ?? .secondaryLabel
        let codeFg = UIColor(markdownHex: appearance.codeForeground) ?? .label
        let codeBg = UIColor(markdownHex: appearance.codeBackground) ?? UIColor.systemGray6

        let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        let h1Font = UIFont.preferredFont(forTextStyle: .title1).withTraits(.traitBold)
        let h2Font = UIFont.preferredFont(forTextStyle: .title3).withTraits(.traitBold)
        let h3Font = UIFont.preferredFont(forTextStyle: .headline)

        for (index, block) in blocks.enumerated() {
            if index > 0 && block != .blank {
                result.append(NSAttributedString(string: "\n"))
            }

            switch block {
            case .h1(let text):
                let attributed = inlineAttributedString(text, font: h1Font, color: accentColor)
                result.append(attributed)

            case .h2(let text):
                let attributed = inlineAttributedString(text, font: h2Font, color: accentColor)
                result.append(attributed)

            case .h3(let text):
                let attributed = inlineAttributedString(text, font: h3Font, color: .label)
                result.append(attributed)

            case .paragraph(let text):
                let attributed = inlineAttributedString(text, font: bodyFont, color: .label)
                result.append(attributed)

            case .listItem(let text, let level):
                let bullet = level == 0 ? "• " : "◦ "
                let indent = String(repeating: "  ", count: level)
                let prefixed = "\(indent)\(bullet)\(text)"
                let attributed = inlineAttributedString(prefixed, font: bodyFont, color: .label)
                result.append(attributed)

            case .orderedListItem(let text, let number):
                let prefixed = "\(number). \(text)"
                let attributed = inlineAttributedString(prefixed, font: bodyFont, color: .label)
                result.append(attributed)

            case .taskListItem(let text, let isChecked):
                let checkbox = isChecked ? "☑ " : "☐ "
                let color: UIColor = isChecked ? .secondaryLabel : .label
                let attributed = inlineAttributedString("\(checkbox)\(text)", font: bodyFont, color: color)
                if isChecked {
                    attributed.addAttribute(
                        .strikethroughStyle,
                        value: NSUnderlineStyle.single.rawValue,
                        range: NSRange(location: 0, length: attributed.length)
                    )
                }
                result.append(attributed)

            case .blockquote(let text):
                let attributed = inlineAttributedString("❝ \(text)", font: bodyFont, color: syntaxColor)
                result.append(attributed)

            case .image(let alt, let url):
                let description = alt.isEmpty ? "🖼 \(url)" : "🖼 \(alt)"
                let attributed = NSMutableAttributedString(
                    string: description,
                    attributes: [.font: bodyFont, .foregroundColor: syntaxColor]
                )
                if let linkURL = URL(string: url) {
                    attributed.addAttribute(.link, value: linkURL, range: NSRange(location: 0, length: attributed.length))
                }
                result.append(attributed)

            case .tagLine(let tags):
                let tagText = tags.map { "#\($0)" }.joined(separator: " ")
                let attributed = NSMutableAttributedString(
                    string: tagText,
                    attributes: [.font: bodyFont, .foregroundColor: accentColor]
                )
                result.append(attributed)

            case .rule:
                let line = String(repeating: "─", count: 40)
                let attributed = NSAttributedString(
                    string: line,
                    attributes: [.font: bodyFont, .foregroundColor: UIColor.separator]
                )
                result.append(attributed)

            case .blank:
                result.append(NSAttributedString(string: "\n"))
            }
        }

        return result
    }

    // MARK: - Inline AttributedString Helpers

    /// Creates a mutable attributed string with inline Markdown rendered.
    private static func inlineAttributedString(
        _ text: String,
        font: UIFont,
        color: UIColor
    ) -> NSMutableAttributedString {
        // Try the system Markdown parser first for inline rendering.
        if let swiftAttr = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            let nsAttr = NSMutableAttributedString(swiftAttr)
            // Apply base font and colour, preserving bold/italic/code traits.
            nsAttr.enumerateAttributes(in: NSRange(location: 0, length: nsAttr.length)) { attrs, range, _ in
                if let existingFont = attrs[.font] as? UIFont {
                    // Preserve bold/italic traits from the Markdown parser.
                    let mergedFont = font.withTraits(existingFont.fontDescriptor.symbolicTraits)
                    nsAttr.addAttribute(.font, value: mergedFont, range: range)
                } else {
                    nsAttr.addAttribute(.font, value: font, range: range)
                }
                if attrs[.foregroundColor] == nil {
                    nsAttr.addAttribute(.foregroundColor, value: color, range: range)
                }
            }
            return nsAttr
        }

        // Fallback: plain text with base styling.
        return NSMutableAttributedString(
            string: text,
            attributes: [.font: font, .foregroundColor: color]
        )
    }
}

// MARK: - UIFont Helpers

private extension UIFont {
    /// Returns a copy of this font with the specified symbolic traits added.
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(
            fontDescriptor.symbolicTraits.union(traits)
        ) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }
}

#endif
