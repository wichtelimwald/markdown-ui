//
//  ContentProvenance.swift
//  AssistanceKit
//
//  Content provenance tracking for imported/suggested content.
//  Per ADR-0009: Visual Distinction + Tap-to-Accept + Source Link.
//

import Foundation

// MARK: - ContentProvenance

/// Tracks the origin and acceptance state of imported or suggested content.
///
/// When content is imported from an external source (e.g., a website via share
/// extension), a `ContentProvenance` record associates the content with its
/// source. The editor can use this to visually distinguish suggested content
/// and offer a tap-to-accept interaction.
///
/// ### Usage
///
/// ```swift
/// let provenance = ContentProvenance(
///     sourceURL: URL(string: "https://example.com/article"),
///     sourceName: "Example Blog",
///     importDate: .now
/// )
/// // Later, when user accepts the content:
/// var accepted = provenance
/// accepted.isAccepted = true
/// ```
///
/// - SeeAlso: ``MarkdownProvenanceProvider`` for querying provenance per block.
/// - SeeAlso: ADR-0009 for the full design rationale.
public struct ContentProvenance: Codable, Sendable, Equatable {

    /// The URL of the original source, if available.
    ///
    /// Example: `https://en.wikipedia.org/wiki/Markdown`
    public let sourceURL: URL?

    /// A human-readable name for the source (e.g., "Wikipedia", "Blog Post").
    ///
    /// Used for display in the source indicator. When `nil`, the editor
    /// may derive a display name from ``sourceURL``.
    public let sourceName: String?

    /// The date and time when the content was imported.
    public let importDate: Date

    /// Whether the user has accepted the suggested content.
    ///
    /// - `false`: Content is displayed as "suggested" with visual distinction.
    /// - `true`: Content has been accepted by the user and renders normally,
    ///   but the source link (🔗) is retained.
    public var isAccepted: Bool

    /// Creates a new content provenance record.
    ///
    /// - Parameters:
    ///   - sourceURL: The URL of the original source. Defaults to `nil`.
    ///   - sourceName: A human-readable source name. Defaults to `nil`.
    ///   - importDate: When the content was imported. Defaults to `.now`.
    ///   - isAccepted: Whether the content is already accepted. Defaults to `false`.
    public init(
        sourceURL: URL? = nil,
        sourceName: String? = nil,
        importDate: Date = .now,
        isAccepted: Bool = false
    ) {
        self.sourceURL = sourceURL
        self.sourceName = sourceName
        self.importDate = importDate
        self.isAccepted = isAccepted
    }

    /// A display-friendly source name, falling back to the source URL host.
    ///
    /// Returns ``sourceName`` if set, otherwise the host portion of
    /// ``sourceURL``, or `nil` if neither is available.
    public var displayName: String? {
        if let sourceName { return sourceName }
        return sourceURL?.host()
    }
}

// MARK: - MarkdownProvenanceProvider

/// Protocol for querying content provenance associated with Markdown blocks.
///
/// Host apps implement this protocol to supply provenance data to the editor.
/// The editor queries the provider to determine which blocks have associated
/// source information and whether they have been accepted.
///
/// ### Implementation
///
/// ```swift
/// struct MyProvenanceProvider: MarkdownProvenanceProvider {
///     func provenance(forBlockAt index: Int) async -> ContentProvenance? {
///         // Look up provenance from your data store
///         return myDatabase.provenance(forBlock: index)
///     }
///
///     func acceptContent(atBlockIndex index: Int) async {
///         // Mark the block's content as accepted
///         myDatabase.accept(block: index)
///     }
/// }
/// ```
///
/// - SeeAlso: ``ContentProvenance`` for the provenance data model.
/// - SeeAlso: ADR-0009 for the full design rationale.
public protocol MarkdownProvenanceProvider: Sendable {

    /// Returns the provenance record for a specific block, if any.
    ///
    /// - Parameter index: The zero-based block index (from ``MarkdownBlockParser``).
    /// - Returns: The ``ContentProvenance`` for the block, or `nil` if the block
    ///   has no associated provenance (i.e., it is user-authored content).
    func provenance(forBlockAt index: Int) async -> ContentProvenance?

    /// Marks the content at the given block index as accepted by the user.
    ///
    /// After acceptance, the block renders normally but retains its source link.
    ///
    /// - Parameter index: The zero-based block index to accept.
    func acceptContent(atBlockIndex index: Int) async
}
