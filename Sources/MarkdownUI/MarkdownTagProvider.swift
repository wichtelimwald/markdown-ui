//
//  MarkdownTagProvider.swift
//  AssistanceKit
//
//  Tag provider protocol for Markdown tag autocompletion.
//  Part of ADR-0008 (Tag System Architecture).
//

import Foundation

// MARK: - MarkdownTag

/// A single Markdown tag with metadata for autocompletion and display.
///
/// Tags are the `#tagname` tokens found in Markdown documents. This model
/// provides the data needed for tag autocompletion UI, filtering, and display.
///
/// ```swift
/// let tag = MarkdownTag(name: "must-do", color: "#FF3B30", usageCount: 12)
/// ```
public struct MarkdownTag: Identifiable, Hashable, Sendable {

    /// Unique identifier for the tag (defaults to the tag name).
    public var id: String { name }

    /// The tag name without the leading `#` (e.g. `"must-do"`).
    public let name: String

    /// Optional hex colour string for tag display (e.g. `"#FF3B30"`).
    ///
    /// When `nil`, the tag uses the theme's accent colour.
    public let color: String?

    /// Number of times the tag appears across all documents.
    ///
    /// Used for sorting suggestions by popularity.
    public let usageCount: Int

    /// Creates a Markdown tag.
    ///
    /// - Parameters:
    ///   - name: Tag name without the leading `#`.
    ///   - color: Optional hex colour string. Defaults to `nil` (accent colour).
    ///   - usageCount: Number of occurrences. Defaults to `0`.
    public init(name: String, color: String? = nil, usageCount: Int = 0) {
        self.name = name
        self.color = color
        self.usageCount = usageCount
    }
}

// MARK: - MarkdownTagProvider

/// Protocol for providing tag autocompletion data to the Markdown editor.
///
/// Implement this protocol in your app to supply the list of known tags
/// for autocompletion when the user types `#` in the editor.
///
/// ```swift
/// struct MyTagProvider: MarkdownTagProvider {
///     func availableTags(matching prefix: String) async -> [MarkdownTag] {
///         // Query your database for tags starting with prefix
///         return database.tags.filter { $0.name.hasPrefix(prefix) }
///     }
///
///     func allTags() async -> [MarkdownTag] {
///         return database.tags
///     }
/// }
/// ```
///
/// Wire the provider into the editor:
///
/// ```swift
/// MarkdownEditorView(text: $text, tagProvider: myTagProvider)
/// ```
///
/// - SeeAlso: ``MarkdownTag`` for the tag data model.
/// - SeeAlso: ADR-0008 for the tag system architecture.
public protocol MarkdownTagProvider: Sendable {

    /// Returns tags matching the given prefix, sorted by relevance.
    ///
    /// Called when the user types `#` followed by characters in the editor.
    /// The prefix does not include the `#` character.
    ///
    /// - Parameter prefix: The characters typed after `#` (may be empty for
    ///   showing all tags).
    /// - Returns: Ordered array of matching tags, typically sorted by
    ///   ``MarkdownTag/usageCount`` (descending).
    func availableTags(matching prefix: String) async -> [MarkdownTag]

    /// Returns all known tags.
    ///
    /// Used for tag management UIs and bulk operations.
    ///
    /// - Returns: All tags in the system.
    func allTags() async -> [MarkdownTag]
}
