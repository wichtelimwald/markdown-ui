//
//  MarkdownSectionParser.swift
//  AssistanceKit
//
//  Section-level Markdown splitter.
//  Generalised from ToogetherCore for cross-project reuse.
//

import Foundation

// MARK: - MarkdownSection

/// A single level-2 section (`## …`) in a Markdown document.
///
/// Used by Markdown editor views to display and edit a Markdown body
/// section by section.
///
/// - SeeAlso: ``MarkdownSectionParser`` for split/join utilities.
public struct MarkdownSection: Identifiable, Hashable, Sendable {

    /// Stable identity across edits within the same session.
    public var id: UUID

    /// The full `## …` heading line, e.g. `"## 📍 Ort / Location"`.
    public var heading: String

    /// The body text below the heading until the next level-2 heading.
    public var body: String

    /// Creates a section.
    ///
    /// - Parameters:
    ///   - id: Stable identity. Defaults to a new UUID.
    ///   - heading: Full `## …` heading line.
    ///   - body: Body text below the heading.
    public init(id: UUID = UUID(), heading: String, body: String) {
        self.id = id
        self.heading = heading
        self.body = body
    }

    /// The heading text with the `## ` prefix stripped.
    ///
    /// For example, `"## 📍 Ort / Location"` becomes `"📍 Ort / Location"`.
    public var displayHeading: String {
        String(heading.drop(while: { $0 == "#" || $0 == " " }))
    }

    /// Whether the body is empty (whitespace-only counts as empty).
    public var isEmpty: Bool {
        body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - MarkdownSectionParser

/// Splits a Markdown body at level-2 headings (`## …`) and reassembles it.
///
/// ### Split rule
///
/// - Lines starting with exactly `## ` (space required) start a new section.
/// - Lines starting with `### ` or deeper are treated as body content.
/// - Content before the first `## ` heading is ignored (rare in generated bodies).
///
/// ### Usage
///
/// ```swift
/// var sections = MarkdownSectionParser.split(markdownBody)
/// sections[0].body = "Updated content"
/// markdownBody = MarkdownSectionParser.join(sections)
/// ```
public enum MarkdownSectionParser {

    // MARK: - Public API

    /// Splits a Markdown body into level-2 sections.
    ///
    /// Returns an empty array when the body contains no `## ` headings.
    ///
    /// - Parameter markdown: The full Markdown body string.
    /// - Returns: Ordered array of ``MarkdownSection`` values.
    public static func split(_ markdown: String) -> [MarkdownSection] {
        let lines = markdown.components(separatedBy: "\n")
        var sections: [MarkdownSection] = []
        var currentHeading: String?
        var currentLines: [String] = []

        for line in lines {
            if isLevel2Heading(line) {
                if let heading = currentHeading {
                    let body = currentLines
                        .joined(separator: "\n")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    sections.append(MarkdownSection(heading: heading, body: body))
                }
                currentHeading = line
                currentLines = []
            } else {
                currentLines.append(line)
            }
        }

        if let heading = currentHeading {
            let body = currentLines
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            sections.append(MarkdownSection(heading: heading, body: body))
        }

        return sections
    }

    /// Joins an ordered array of ``MarkdownSection`` values back into a
    /// Markdown body string.
    ///
    /// Empty sections produce only their heading line (no trailing newline).
    /// Non-empty sections produce `"<heading>\n<body>"`.
    /// Sections are separated by a blank line.
    ///
    /// - Parameter sections: The ordered sections to join.
    /// - Returns: A single Markdown body string.
    public static func join(_ sections: [MarkdownSection]) -> String {
        sections.map { section in
            section.isEmpty ? section.heading : "\(section.heading)\n\(section.body)"
        }.joined(separator: "\n\n")
    }

    // MARK: - Private

    /// Returns `true` when `line` is a level-2 Markdown heading (`## …`).
    ///
    /// A line is level-2 when it starts with exactly two `#` characters
    /// followed by a space — not three or more (which would be level 3+).
    private static func isLevel2Heading(_ line: String) -> Bool {
        line.hasPrefix("## ") && !line.hasPrefix("### ")
    }
}
