//
//  MarkdownBlockParser.swift
//  AssistanceKit
//
//  Block-level Markdown parser.
//  Generalised from ToogetherCore for cross-project reuse.
//

import Foundation

// MARK: - MarkdownBlock

/// A block-level element parsed from a Markdown document.
///
/// Used by ``MarkdownBlockParser`` to produce a flat list of blocks for
/// rendering in a reading view (headings, paragraphs, lists, blockquotes,
/// images).
///
/// - SeeAlso: ``MarkdownBlockParser`` for the parsing logic.
/// - SeeAlso: ``MarkdownSectionParser`` for section-level splitting.
public enum MarkdownBlock: Equatable, Sendable {
    /// Level-1 heading (`# …`).
    case h1(String)
    /// Level-2 heading (`## …`).
    case h2(String)
    /// Level-3 heading (`### …`).
    case h3(String)
    /// One or more consecutive lines of paragraph text (may contain inline Markdown).
    case paragraph(String)
    /// Unordered list item with indent level (0-based, 2 spaces per level).
    case listItem(String, Int)
    /// Ordered list item with sequential number.
    case orderedListItem(String, Int)
    /// Blockquote line (`> …`).
    case blockquote(String)
    /// Image reference (`![alt](url)`).
    case image(alt: String, url: String)
    /// Task list item — unchecked (`- [ ]`) or checked (`- [x]`/`- [X]`).
    ///
    /// - Parameters:
    ///   - text: The task text after the checkbox marker.
    ///   - isChecked: Whether the task is checked (`[x]` / `[X]`) or unchecked (`[ ]`).
    case taskListItem(String, Bool)
    /// Tag line containing one or more `#tag` tokens (e.g. `#must-do #zoo 🦁`).
    ///
    /// - Parameter tags: The extracted tag names (without leading `#`).
    case tagLine([String])
    /// Horizontal rule (`---`, `***`, or `___`).
    case rule
    /// Visual spacing between blocks.
    case blank
}

// MARK: - MarkdownBlockParser

/// Parses a Markdown string into an ordered array of ``MarkdownBlock`` values.
///
/// ### Supported blocks
///
/// | Markdown syntax        | Block                          |
/// |------------------------|--------------------------------|
/// | `# Title`              | `.h1("Title")`                 |
/// | `## Heading`           | `.h2("Heading")`               |
/// | `### Sub`              | `.h3("Sub")`                   |
/// | `- item` / `* item`    | `.listItem("item", indent)`    |
/// | `- [ ] item`           | `.taskListItem("item", false)` |
/// | `- [x] item`           | `.taskListItem("item", true)`  |
/// | `1. item`              | `.orderedListItem("item", 1)`  |
/// | `> quote`              | `.blockquote("quote")`         |
/// | `![alt](url)`          | `.image(alt:url:)`             |
/// | `---` / `***` / `___`  | `.rule`                        |
/// | blank line             | `.blank`                       |
/// | anything else          | `.paragraph("text")`           |
///
/// ### Tag lines
///
/// Lines consisting only of `#tag` tokens (e.g. `#must-do #zoo 🦁`) are
/// silently skipped — they are typically rendered separately in the UI.
///
/// ### Paragraph grouping
///
/// Consecutive non-block lines are merged into a single `.paragraph` block.
///
/// - SeeAlso: ``MarkdownSectionParser`` for splitting at level-2 headings.
public enum MarkdownBlockParser {

    // MARK: - Public API

    /// Parses a Markdown string into block-level elements.
    ///
    /// - Parameter markdown: The raw Markdown string.
    /// - Returns: An ordered array of ``MarkdownBlock`` values.
    public static func parse(_ markdown: String) -> [MarkdownBlock] {
        let lines = markdown.components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var paragraphLines: [String] = []

        func flushParagraph() {
            let text = paragraphLines
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                blocks.append(.paragraph(text))
            }
            paragraphLines = []
        }

        var orderedCounter = 0

        for line in lines {
            // --- Headings: checked H3 → H2 → H1 to avoid prefix collisions ---
            if line.hasPrefix("### ") {
                flushParagraph()
                blocks.append(.h3(String(line.dropFirst(4))))
                orderedCounter = 0
                continue
            }
            if line.hasPrefix("## ") {
                flushParagraph()
                blocks.append(.h2(String(line.dropFirst(3))))
                orderedCounter = 0
                continue
            }
            if line.hasPrefix("# ") {
                flushParagraph()
                blocks.append(.h1(String(line.dropFirst(2))))
                orderedCounter = 0
                continue
            }

            // --- Horizontal rule ---
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushParagraph()
                blocks.append(.rule)
                orderedCounter = 0
                continue
            }

            // --- Image ---
            if let imageBlock = parseImageLine(line) {
                flushParagraph()
                blocks.append(imageBlock)
                orderedCounter = 0
                continue
            }

            // --- Blockquote ---
            if line.hasPrefix("> ") {
                flushParagraph()
                blocks.append(.blockquote(String(line.dropFirst(2))))
                orderedCounter = 0
                continue
            }
            if line.hasPrefix(">") && line.count > 1 {
                flushParagraph()
                blocks.append(.blockquote(String(line.dropFirst(1))))
                orderedCounter = 0
                continue
            }

            // --- Task list (must come before unordered list) ---
            if let taskBlock = parseTaskListLine(line) {
                flushParagraph()
                blocks.append(taskBlock)
                orderedCounter = 0
                continue
            }

            // --- Unordered list (2 spaces = one indent level) ---
            if let listBlock = parseUnorderedListLine(line) {
                flushParagraph()
                blocks.append(listBlock)
                orderedCounter = 0
                continue
            }

            // --- Ordered list ---
            if let orderedBlock = parseOrderedListLine(line) {
                flushParagraph()
                orderedCounter += 1
                // Replace the parsed number with the sequential counter
                if case .orderedListItem(let text, _) = orderedBlock {
                    blocks.append(.orderedListItem(text, orderedCounter))
                }
                continue
            }
            orderedCounter = 0

            // --- Blank line ---
            if trimmed.isEmpty {
                flushParagraph()
                if let last = blocks.last, case .blank = last {
                    // already blank — skip duplicate
                } else if !blocks.isEmpty {
                    blocks.append(.blank)
                }
                continue
            }

            // --- Tag line (extract tags and emit as block) ---
            if isTagLine(line) {
                flushParagraph()
                blocks.append(.tagLine(extractTags(from: line)))
                continue
            }

            // --- Regular paragraph text ---
            paragraphLines.append(line)
        }

        flushParagraph()

        // Remove trailing blanks
        while let last = blocks.last, case .blank = last {
            blocks.removeLast()
        }

        return blocks
    }

    // MARK: - Tag Detection

    /// Returns `true` when a line is a Markdown tag line (e.g. `#must-do #zoo 🦁`).
    ///
    /// A tag line starts with `#` but is not a heading (`# `, `## `, `### `),
    /// and contains at least one valid `#tag` pattern (hash followed by a letter).
    public static func isTagLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#"),
              !trimmed.hasPrefix("# "),
              !trimmed.hasPrefix("## "),
              !trimmed.hasPrefix("### ") else { return false }
        // Tag pattern: `#` followed by a letter (incl. German umlauts), then any
        // word characters or hyphens. Matches tags like `#must-do`, `#zoo`, `#Bücher`.
        let tagPattern = #"#[a-zA-ZäöüÄÖÜß][a-zA-Z0-9äöüÄÖÜß-]*"#
        guard let regex = try? NSRegularExpression(pattern: tagPattern),
              regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil
        else { return false }
        return true
    }

    /// Extracts tag names (without leading `#`) from a tag line.
    ///
    /// For example, `"#must-do #zoo 🦁"` returns `["must-do", "zoo"]`.
    ///
    /// - Parameter line: A tag line string.
    /// - Returns: Ordered array of tag names found in the line.
    public static func extractTags(from line: String) -> [String] {
        let tagPattern = #"#([a-zA-ZäöüÄÖÜß][a-zA-Z0-9äöüÄÖÜß-]*)"#
        guard let regex = try? NSRegularExpression(pattern: tagPattern) else { return [] }
        let range = NSRange(line.startIndex..., in: line)
        let matches = regex.matches(in: line, range: range)
        return matches.compactMap { match in
            guard match.numberOfRanges >= 2,
                  let tagRange = Range(match.range(at: 1), in: line) else { return nil }
            return String(line[tagRange])
        }
    }

    // MARK: - Active Block Detection

    /// Maps a cursor offset (character position) to the index of the block
    /// containing it in the parsed block array.
    ///
    /// This is the foundation for live preview: the host editor calls this
    /// method on every cursor movement to determine which block is "active"
    /// (being edited). The active block can then be shown in raw Markdown
    /// while inactive blocks are rendered.
    ///
    /// - Parameters:
    ///   - offset: The character offset of the cursor within the Markdown string.
    ///   - markdown: The full Markdown string (same string that was parsed).
    /// - Returns: The zero-based index into the ``parse(_:)`` result array,
    ///   or `nil` if the offset is out of range or the document is empty.
    public static func blockIndex(at offset: Int, in markdown: String) -> Int? {
        guard !markdown.isEmpty, offset >= 0, offset <= (markdown as NSString).length else { return nil }

        let lines = markdown.components(separatedBy: "\n")
        var lineRanges: [(start: Int, end: Int)] = []
        var pos = 0
        for line in lines {
            let lineLen = (line as NSString).length
            lineRanges.append((start: pos, end: pos + lineLen))
            pos += lineLen + 1 // +1 for the newline
        }

        // Determine which line the cursor is on
        let cursorLine: Int
        if offset >= pos {
            cursorLine = lines.count - 1
        } else {
            cursorLine = lineRanges.firstIndex(where: { offset >= $0.start && offset <= $0.end })
                ?? lines.count - 1
        }

        // Walk the lines using the same logic as parse() to map line → block index
        var blockIndex = 0
        var inParagraph = false
        var lastWasBlank = false
        var orderedCounter = 0

        for (lineIndex, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Heading
            if line.hasPrefix("### ") || line.hasPrefix("## ") || line.hasPrefix("# ") {
                if inParagraph { blockIndex += 1; inParagraph = false }
                if lineIndex == cursorLine { return blockIndex }
                blockIndex += 1
                lastWasBlank = false
                orderedCounter = 0
                continue
            }

            // Horizontal rule
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                if inParagraph { blockIndex += 1; inParagraph = false }
                if lineIndex == cursorLine { return blockIndex }
                blockIndex += 1
                lastWasBlank = false
                orderedCounter = 0
                continue
            }

            // Image
            if parseImageLine(line) != nil {
                if inParagraph { blockIndex += 1; inParagraph = false }
                if lineIndex == cursorLine { return blockIndex }
                blockIndex += 1
                lastWasBlank = false
                orderedCounter = 0
                continue
            }

            // Blockquote
            if line.hasPrefix("> ") || (line.hasPrefix(">") && line.count > 1) {
                if inParagraph { blockIndex += 1; inParagraph = false }
                if lineIndex == cursorLine { return blockIndex }
                blockIndex += 1
                lastWasBlank = false
                orderedCounter = 0
                continue
            }

            // Task list (before unordered list)
            if parseTaskListLine(line) != nil {
                if inParagraph { blockIndex += 1; inParagraph = false }
                if lineIndex == cursorLine { return blockIndex }
                blockIndex += 1
                lastWasBlank = false
                orderedCounter = 0
                continue
            }

            // Unordered list
            if parseUnorderedListLine(line) != nil {
                if inParagraph { blockIndex += 1; inParagraph = false }
                if lineIndex == cursorLine { return blockIndex }
                blockIndex += 1
                lastWasBlank = false
                orderedCounter = 0
                continue
            }

            // Ordered list
            if parseOrderedListLine(line) != nil {
                if inParagraph { blockIndex += 1; inParagraph = false }
                orderedCounter += 1
                if lineIndex == cursorLine { return blockIndex }
                blockIndex += 1
                lastWasBlank = false
                continue
            }
            orderedCounter = 0

            // Blank line
            if trimmed.isEmpty {
                if inParagraph { blockIndex += 1; inParagraph = false }
                if !lastWasBlank && blockIndex > 0 {
                    if lineIndex == cursorLine { return blockIndex }
                    blockIndex += 1
                    lastWasBlank = true
                } else if lineIndex == cursorLine {
                    // Cursor on a duplicate blank or leading blank
                    return max(0, blockIndex - 1)
                }
                continue
            }
            lastWasBlank = false

            // Tag line
            if isTagLine(line) {
                if inParagraph { blockIndex += 1; inParagraph = false }
                if lineIndex == cursorLine { return blockIndex }
                blockIndex += 1
                continue
            }

            // Paragraph continuation
            if !inParagraph {
                inParagraph = true
            }
            if lineIndex == cursorLine { return blockIndex }
        }

        // If we got here, cursor is at the very end
        if inParagraph { return blockIndex }
        return max(0, blockIndex - 1)
    }

    // MARK: - Line Classification Helpers

    /// Returns `true` if the line is an image (`![alt](url)`).
    public static func isImageLine(_ line: String) -> Bool {
        parseImageLine(line) != nil
    }

    /// Returns `true` if the line is a task list item (`- [ ] text` or `- [x] text`).
    public static func isTaskListLine(_ line: String) -> Bool {
        parseTaskListLine(line) != nil
    }

    /// Returns `true` if the line is an unordered list item (`- text`, `* text`, `+ text`).
    public static func isUnorderedListLine(_ line: String) -> Bool {
        parseUnorderedListLine(line) != nil
    }

    /// Returns `true` if the line is an ordered list item (`1. text`).
    public static func isOrderedListLine(_ line: String) -> Bool {
        parseOrderedListLine(line) != nil
    }

    // MARK: - Internal Helpers

    /// Parses an image line `![alt](url)`.
    private static func parseImageLine(_ line: String) -> MarkdownBlock? {
        let pattern = #"^!\[([^\]]*)\]\(([^)]+)\)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: line, range: NSRange(line.startIndex..., in: line)
              ) else { return nil }
        let nsLine = line as NSString
        let alt = match.range(at: 1).length > 0 ? nsLine.substring(with: match.range(at: 1)) : ""
        let url = nsLine.substring(with: match.range(at: 2))
        return .image(alt: alt, url: url)
    }

    /// Number of leading spaces that constitute one indent level for nested lists.
    private static let spacesPerIndentLevel = 2

    /// Parses an unordered list line (`- item`, `* item`, `+ item`).
    private static func parseUnorderedListLine(_ line: String) -> MarkdownBlock? {
        let pattern = #"^( *)([-*+]) (.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: line, range: NSRange(line.startIndex..., in: line)
              ) else { return nil }
        let nsLine = line as NSString
        let indent = match.range(at: 1).length / spacesPerIndentLevel
        let text = nsLine.substring(with: match.range(at: 3))
        return .listItem(text, indent)
    }

    /// Parses an ordered list line (`1. item`).
    private static func parseOrderedListLine(_ line: String) -> MarkdownBlock? {
        let pattern = #"^\d+\. (.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: line, range: NSRange(line.startIndex..., in: line)
              ) else { return nil }
        let nsLine = line as NSString
        let text = nsLine.substring(with: match.range(at: 1))
        return .orderedListItem(text, 0) // caller assigns sequential number
    }

    /// Parses a task list line (`- [ ] item`, `- [x] item`, `* [ ] item`, `* [x] item`).
    ///
    /// Task list items use the standard Markdown checkbox syntax: a list marker
    /// (`-`, `*`, or `+`) followed by `[ ]` (unchecked) or `[x]`/`[X]` (checked),
    /// then the task text.
    private static func parseTaskListLine(_ line: String) -> MarkdownBlock? {
        let pattern = #"^\s*[-*+] \[([ xX])\] (.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: line, range: NSRange(line.startIndex..., in: line)
              ) else { return nil }
        let nsLine = line as NSString
        let checkMark = nsLine.substring(with: match.range(at: 1))
        let text = nsLine.substring(with: match.range(at: 2))
        let isChecked = (checkMark == "x" || checkMark == "X")
        return .taskListItem(text, isChecked)
    }
}

// MARK: - Tag Prefix Extraction

/// Result of extracting a `#tag` prefix from text at a cursor position.
///
/// Used by ``MarkdownTagCompletionView`` to determine what the user is typing
/// and which range to replace upon tag selection.
public struct TagPrefixResult: Equatable, Sendable {
    /// The characters after `#` that the user has typed so far (e.g. `"mus"` for `#mus`).
    public let prefix: String
    /// The range in the text covering `#prefix` (used for replacement).
    public let range: NSRange
}

/// Extracts the `#tag` prefix at the given cursor offset in the text.
///
/// Returns `nil` when the cursor is not inside a `#tag` token. A valid tag
/// prefix starts with `#` preceded by whitespace (or at line start), followed
/// by zero or more allowed tag characters (letters, digits, `_`, `-`).
///
/// - Parameters:
///   - offset: The cursor position (UTF-16 offset) in the text.
///   - text: The full text being edited.
/// - Returns: The extracted prefix and its range, or `nil` if none found.
public func extractTagPrefix(at offset: Int, in text: String) -> TagPrefixResult? {
    let nsText = text as NSString
    guard offset >= 1, offset <= nsText.length else { return nil }

    // Scan backwards from cursor to find `#`.
    var hashPos = offset - 1
    while hashPos >= 0 {
        let scalar = UnicodeScalar(nsText.character(at: hashPos))
        guard let scalar else { return nil }
        let char = Character(scalar)
        // Tag chars: letters, digits, underscore, hyphen.
        let isTagChar = char.isLetter || char.isNumber || char == "_" || char == "-"
        if isTagChar {
            hashPos -= 1
            continue
        }
        if char == "#" {
            break
        }
        return nil // Non-tag, non-hash character — not in a tag.
    }

    guard hashPos >= 0, nsText.character(at: hashPos) == 0x23 /* '#' */ else {
        return nil
    }

    // `#` must be preceded by whitespace, start of line, or start of text.
    if hashPos > 0 {
        let scalar = UnicodeScalar(nsText.character(at: hashPos - 1))
        guard let scalar else { return nil }
        let preceding = Character(scalar)
        guard preceding.isWhitespace || preceding.isNewline else { return nil }
    }

    // `#` must be followed by a letter (not a digit or space — that would be a heading).
    // When afterHash == offset (empty prefix, cursor right after `#`), skip this check
    // to allow showing all tags.
    let afterHash = hashPos + 1
    if afterHash < nsText.length, afterHash < offset {
        let scalar = UnicodeScalar(nsText.character(at: afterHash))
        guard let scalar else { return nil }
        let firstAfter = Character(scalar)
        guard firstAfter.isLetter else { return nil }
    }

    let prefixStart = hashPos + 1
    let prefix = nsText.substring(with: NSRange(location: prefixStart, length: offset - prefixStart))
    let range = NSRange(location: hashPos, length: offset - hashPos)
    return TagPrefixResult(prefix: prefix, range: range)
}

// MARK: - Image Insertion Helpers

/// Generates Markdown image syntax from a URL and optional alt text.
///
/// - Parameters:
///   - url: The image URL string.
///   - altText: Optional alt text for accessibility. Defaults to `""`.
///     For best accessibility, always provide a meaningful description.
/// - Returns: The Markdown image syntax (e.g. `![Photo](https://example.com/img.jpg)`).
public func markdownImageSyntax(url: String, altText: String = "") -> String {
    "![\(altText)](\(url))"
}

/// Generates a suggested filename for a photo based on the current date.
///
/// Use this when implementing ``MarkdownImageInsertionDelegate`` to create
/// consistent, date-stamped filenames for stored images.
///
/// - Returns: A filename like `"photo-2026-04-14-143052.jpg"`.
public func suggestedPhotoFilename() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd-HHmmss"
    return "photo-\(formatter.string(from: Date())).jpg"
}
