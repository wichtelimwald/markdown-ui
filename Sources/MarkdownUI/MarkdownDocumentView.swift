//
//  MarkdownDocumentView.swift
//  AssistanceKit
//
//  Renders a Markdown body as a readable document (Obsidian-style).
//  Generalised from toogether for cross-project reuse.
//

#if canImport(SwiftUI)
import SwiftUI

// MARK: - MarkdownImageDataProvider

/// Protocol for resolving image data from custom URL schemes in Markdown.
///
/// Implement this protocol to handle app-specific image references (e.g.
/// `local://activity-img-abc.jpg`) in ``MarkdownDocumentView``.
///
/// ```swift
/// struct MyImageStore: MarkdownImageDataProvider {
///     let localScheme = "local://"
///     func imageData(for reference: String) -> Data? {
///         // Load image data from your storage
///     }
/// }
/// ```
public protocol MarkdownImageDataProvider: Sendable {
    /// The URL scheme prefix that identifies local/custom image references.
    ///
    /// For example, `"local://"`. Image URLs starting with this prefix will be
    /// resolved using ``imageData(for:)``.
    var localScheme: String { get }

    /// Returns the raw image data for a given reference string.
    ///
    /// - Parameter reference: The full image URL string (e.g. `"local://img-abc.jpg"`).
    /// - Returns: The image data, or `nil` if the reference cannot be resolved.
    func imageData(for reference: String) -> Data?
}

// MARK: - MarkdownDocumentView

/// Renders a Markdown body as a readable document (Obsidian-style).
///
/// Parses the Markdown string into block-level elements — headings, paragraphs,
/// lists, blockquotes, and images — and renders each with appropriate SwiftUI
/// typography.
///
/// Unlike ``MarkdownText`` (inline-only), `MarkdownDocumentView` handles the
/// full block grammar so headings render large, lists render as bullet points,
/// and the document looks like a note — not a form.
///
/// ### Usage
///
/// ```swift
/// MarkdownDocumentView("# Title\n\nSome **bold** text")
/// ```
///
/// With a custom image provider:
///
/// ```swift
/// MarkdownDocumentView(markdown, imageDataProvider: myStore)
/// ```
///
/// With task list toggle callback:
///
/// ```swift
/// MarkdownDocumentView(markdown) { index, isChecked in
///     // Toggle the task at the given block index
/// }
/// ```
///
/// ### Section Collapse
///
/// Enable ``sectionsCollapsible`` to let users tap headings to collapse/expand
/// the content beneath them. Sections collapse up to the next heading at the
/// same or higher level.
///
/// ```swift
/// MarkdownDocumentView(markdown, sectionsCollapsible: true)
/// ```
///
/// - SeeAlso: ``MarkdownEditorView`` for the editing counterpart.
public struct MarkdownDocumentView: View {

    // MARK: - Properties

    private let blocks: [MarkdownBlock]
    private let imageDataProvider: (any MarkdownImageDataProvider)?

    /// Called when a task list checkbox is tapped.
    ///
    /// - Parameters:
    ///   - blockIndex: The index of the toggled task in the block array.
    ///   - isChecked: The new checked state after the toggle.
    private let onTaskToggle: ((Int, Bool) -> Void)?

    /// Called when a tag is tapped in the rendered view.
    ///
    /// Receives the tag name without the leading `#` (e.g. `"must-do"`).
    private let onTagTapped: ((String) -> Void)?

    /// When `true`, headings can be tapped to collapse/expand their sections.
    /// A chevron indicator shows the collapsed state.
    private let sectionsCollapsible: Bool

    /// Optional provider for content provenance (per ADR-0009).
    ///
    /// When set, blocks with associated provenance are visually distinguished
    /// from user-authored content. Suggested blocks show a tinted background,
    /// accent border, source label, and an "Accept" button.
    private let provenanceProvider: (any MarkdownProvenanceProvider)?

    /// Called when a source link is tapped on an accepted block.
    ///
    /// Receives the source URL from the block's ``ContentProvenance``.
    /// The host app is responsible for opening the URL (keeping the view pure).
    private let onSourceLinkTapped: ((URL) -> Void)?

    /// Indices of currently collapsed sections (keyed by heading block index).
    @State private var collapsedSections: Set<Int> = []

    /// Cached provenance records per block index, loaded asynchronously.
    @State private var provenanceCache: [Int: ContentProvenance] = [:]

    // MARK: - Init

    /// Creates a document view.
    ///
    /// - Parameters:
    ///   - markdown: Raw Markdown string to render.
    ///   - imageDataProvider: Optional provider for resolving custom image references.
    ///   - sectionsCollapsible: Whether headings can be tapped to collapse/expand
    ///     their content. Defaults to `false`.
    ///   - provenanceProvider: Optional provider for content provenance. When set,
    ///     blocks with provenance are visually styled per ADR-0009.
    ///   - onTaskToggle: Optional callback fired when a task checkbox is tapped.
    ///     Receives the block index and the new checked state.
    ///   - onTagTapped: Optional callback fired when a tag is tapped.
    ///     Receives the tag name without the leading `#`.
    ///   - onSourceLinkTapped: Optional callback fired when a source link is tapped
    ///     on an accepted block. Receives the source URL.
    public init(
        _ markdown: String,
        imageDataProvider: (any MarkdownImageDataProvider)? = nil,
        sectionsCollapsible: Bool = false,
        provenanceProvider: (any MarkdownProvenanceProvider)? = nil,
        onTaskToggle: ((Int, Bool) -> Void)? = nil,
        onTagTapped: ((String) -> Void)? = nil,
        onSourceLinkTapped: ((URL) -> Void)? = nil
    ) {
        self.imageDataProvider = imageDataProvider
        self.sectionsCollapsible = sectionsCollapsible
        self.provenanceProvider = provenanceProvider
        self.onTaskToggle = onTaskToggle
        self.onTagTapped = onTagTapped
        self.onSourceLinkTapped = onSourceLinkTapped
        self.blocks = MarkdownBlockParser.parse(markdown)
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                if !isBlockHiddenByCollapse(index: index) {
                    provenanceWrappedBlockView(block, index: index)
                }
            }
        }
        .task {
            guard let provider = provenanceProvider else { return }
            await loadAllProvenance(provider: provider)
        }
    }

    // MARK: - Provenance Loading

    /// Loads provenance for all blocks from the provider.
    private func loadAllProvenance(provider: any MarkdownProvenanceProvider) async {
        for index in blocks.indices {
            if let provenance = await provider.provenance(forBlockAt: index) {
                provenanceCache[index] = provenance
            }
        }
    }

    // MARK: - Provenance-Wrapped Block Rendering

    /// Wraps a block view with provenance styling when applicable.
    @ViewBuilder
    private func provenanceWrappedBlockView(_ block: MarkdownBlock, index: Int) -> some View {
        let provenance = provenanceCache[index]

        if let provenance, !provenance.isAccepted {
            // Suggested (not yet accepted): tinted background + accent border + source label + accept button
            suggestedBlockView(block, index: index, provenance: provenance)
        } else if let provenance, provenance.isAccepted {
            // Accepted: normal rendering + persistent source link
            VStack(alignment: .leading, spacing: 0) {
                blockView(block, index: index)
                sourceLinkView(provenance: provenance)
            }
        } else {
            // No provenance: standard rendering
            blockView(block, index: index)
        }
    }

    // MARK: - Suggested Block Styling (AK-072)

    /// Renders a block with suggested-content visual styling per ADR-0009.
    ///
    /// Visual treatment:
    /// - Tinted background (accent color at 6% opacity)
    /// - Left accent border (3pt, accent color at 40%)
    /// - Source name label at top-right
    /// - "Accept" button at bottom-right
    @ViewBuilder
    private func suggestedBlockView(
        _ block: MarkdownBlock,
        index: Int,
        provenance: ContentProvenance
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Source label
            if let displayName = provenance.displayName {
                HStack {
                    Spacer()
                    Text(displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            // Block content
            blockView(block, index: index)

            // Accept button
            HStack {
                Spacer()
                Button {
                    acceptBlock(at: index)
                } label: {
                    Label("Accept", systemImage: "checkmark.circle")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Accept suggested content")
                .accessibilityHint("Double tap to accept this imported content")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Color.accentColor.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 6)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.accentColor.opacity(0.4))
                .frame(width: 3)
        }
        .padding(.top, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Suggested content from \(provenance.displayName ?? "unknown source")")
    }

    // MARK: - Tap-to-Accept (AK-073)

    /// Accepts the suggested content at the given block index.
    private func acceptBlock(at index: Int) {
        guard let provider = provenanceProvider else { return }
        Task {
            await provider.acceptContent(atBlockIndex: index)
            // Update local cache to reflect acceptance
            withAnimation(.easeInOut(duration: 0.2)) {
                if var provenance = provenanceCache[index] {
                    provenance.isAccepted = true
                    provenanceCache[index] = provenance
                }
            }
        }
    }

    // MARK: - Source Link Display (AK-074)

    /// Shows a persistent source link icon for accepted provenance blocks.
    @ViewBuilder
    private func sourceLinkView(provenance: ContentProvenance) -> some View {
        if let sourceURL = provenance.sourceURL {
            HStack(spacing: 4) {
                Spacer()
                if let onSourceLinkTapped {
                    Button {
                        onSourceLinkTapped(sourceURL)
                    } label: {
                        sourceLinkLabel(provenance: provenance)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Source: \(provenance.displayName ?? sourceURL.absoluteString)")
                    .accessibilityAddTraits(.isLink)
                    .accessibilityHint("Double tap to open original source")
                } else {
                    sourceLinkLabel(provenance: provenance)
                        .accessibilityLabel("Source: \(provenance.displayName ?? sourceURL.absoluteString)")
                }
            }
            .padding(.top, 2)
        }
    }

    /// The visual label for a source link (🔗 icon + display name).
    private func sourceLinkLabel(provenance: ContentProvenance) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "link")
                .font(.caption2)
            if let displayName = provenance.displayName {
                Text(displayName)
                    .font(.caption2)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(.secondary)
    }

    // MARK: - Block Rendering

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock, index: Int) -> some View {
        switch block {
        case .h1(let text):
            headingView(text: text, font: .title.bold(), topPadding: index == 0 ? 0 : 24, index: index)

        case .h2(let text):
            headingView(text: text, font: .title3.bold(), topPadding: index == 0 ? 0 : 20, index: index)

        case .h3(let text):
            headingView(text: text, font: .headline, topPadding: 12, index: index)

        case .paragraph(let text):
            MarkdownText(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
                .accessibilityLabel(text)

        case .listItem(let text, let level):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(level == 0 ? "•" : "◦")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                MarkdownText(text)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, CGFloat(level) * 16)
            .padding(.top, 2)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("List item, \(text)")

        case .orderedListItem(let text, let number):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(number).")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 20, alignment: .trailing)
                    .accessibilityHidden(true)
                MarkdownText(text)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 2)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Item \(number), \(text)")

        case .taskListItem(let text, let isChecked):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .font(.body)
                    .foregroundStyle(isChecked ? Color.accentColor : .secondary)
                    .onTapGesture {
                        onTaskToggle?(index, !isChecked)
                    }
                    .accessibilityHidden(true)
                MarkdownText(text)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .strikethrough(isChecked)
                    .foregroundStyle(isChecked ? .secondary : .primary)
            }
            .padding(.top, 2)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(isChecked ? "Completed: \(text)" : "To do: \(text)")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(isChecked ? "Double tap to mark as incomplete" : "Double tap to mark as complete")

        case .blockquote(let text):
            HStack(alignment: .top, spacing: 8) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 3)
                    .accessibilityHidden(true)
                MarkdownText(text)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 4)
            .padding(.leading, 4)
            .padding(.top, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Quote: \(text)")

        case .rule:
            Divider()
                .padding(.vertical, 12)
                .accessibilityLabel("Separator")

        case .tagLine(let tags):
            tagLineView(tags: tags)
                .padding(.top, 2)

        case .image(let alt, let url):
            imageView(url: url, alt: alt)
                .padding(.top, 8)
                .accessibilityLabel(alt.isEmpty ? "Image" : alt)

        case .blank:
            Color.clear.frame(height: 8)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Heading with Collapse/Expand

    @ViewBuilder
    private func headingView(text: String, font: Font, topPadding: CGFloat, index: Int) -> some View {
        if sectionsCollapsible {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if collapsedSections.contains(index) {
                        collapsedSections.remove(index)
                    } else {
                        collapsedSections.insert(index)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(text)
                        .font(font)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(collapsedSections.contains(index) ? .zero : .degrees(90))
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
            .padding(.top, topPadding)
            .padding(.bottom, 4)
            .accessibilityLabel(headingAccessibilityLabel(text, block: blocks[index]))
            .accessibilityHint(collapsedSections.contains(index) ? "Double tap to expand section" : "Double tap to collapse section")
            .accessibilityAddTraits([.isButton, .isHeader])
        } else {
            Text(text)
                .font(font)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, topPadding)
                .padding(.bottom, 4)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel(headingAccessibilityLabel(text, block: blocks[index]))
        }
    }

    /// Returns a VoiceOver-friendly label for a heading block.
    ///
    /// Prefixes the heading text with its level for screen reader clarity,
    /// e.g. "Heading level 2, Location".
    private func headingAccessibilityLabel(_ text: String, block: MarkdownBlock) -> String {
        let level = headingLevel(block)
        return "Heading level \(level), \(text)"
    }

    // MARK: - Section Collapse Logic

    /// Returns `true` if the block at `index` is hidden because its parent
    /// heading section is collapsed.
    ///
    /// A heading "owns" all subsequent blocks until the next heading at the
    /// same or higher level. Collapsing a heading hides those owned blocks.
    private func isBlockHiddenByCollapse(index: Int) -> Bool {
        guard sectionsCollapsible, !collapsedSections.isEmpty else { return false }

        // Walk backward from this block to find the nearest heading at each level.
        // If any heading that "owns" this block is collapsed, the block is hidden.
        let block = blocks[index]

        // Headings themselves are never hidden (they are the toggle targets).
        if isHeading(block) { return false }

        // Find the nearest heading before this block.
        var ownerIndex: Int?
        for i in stride(from: index - 1, through: 0, by: -1) {
            if isHeading(blocks[i]) {
                ownerIndex = i
                break
            }
        }

        guard let ownerIndex else { return false }

        // Check if the owner heading is collapsed.
        if collapsedSections.contains(ownerIndex) {
            return true
        }

        // Also check if a higher-level heading that contains the owner is collapsed.
        let ownerLevel = headingLevel(blocks[ownerIndex])
        for i in stride(from: ownerIndex - 1, through: 0, by: -1) {
            let ancestor = blocks[i]
            if isHeading(ancestor) {
                let ancestorLevel = headingLevel(ancestor)
                if ancestorLevel < ownerLevel, collapsedSections.contains(i) {
                    return true
                }
                // Stop once we reach a heading at or above the owner's level.
                if ancestorLevel <= ownerLevel {
                    break
                }
            }
        }

        return false
    }

    /// Returns `true` if the block is any heading (h1, h2, h3).
    private func isHeading(_ block: MarkdownBlock) -> Bool {
        switch block {
        case .h1, .h2, .h3: return true
        default: return false
        }
    }

    /// Returns the heading level (1, 2, 3) or `Int.max` for non-headings.
    private func headingLevel(_ block: MarkdownBlock) -> Int {
        switch block {
        case .h1: return 1
        case .h2: return 2
        case .h3: return 3
        default: return Int.max
        }
    }

    // MARK: - Tag Rendering

    /// Renders a row of tappable tag chips for a `tagLine` block.
    @ViewBuilder
    private func tagLineView(tags: [String]) -> some View {
        HStack(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                tagChip(tag)
            }
            Spacer()
        }
    }

    /// A single tappable tag chip.
    @ViewBuilder
    private func tagChip(_ tag: String) -> some View {
        if onTagTapped != nil {
            Button {
                onTagTapped?(tag)
            } label: {
                Text("#\(tag)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tag: \(tag)")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Double tap to filter by this tag")
        } else {
            Text("#\(tag)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.12), in: Capsule())
                .accessibilityLabel("Tag: \(tag)")
        }
    }

    // MARK: - Image Rendering

    @ViewBuilder
    private func imageView(url: String, alt: String) -> some View {
        if let provider = imageDataProvider, url.hasPrefix(provider.localScheme) {
            localImageView(provider: provider, reference: url, altText: alt)
        } else if let imageURL = URL(string: url) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .failure:
                    imagePlaceholder(alt: alt)
                default:
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 80)
                }
            }
        } else {
            imagePlaceholder(alt: alt)
        }
    }

    @ViewBuilder
    private func localImageView(
        provider: any MarkdownImageDataProvider,
        reference: String,
        altText: String
    ) -> some View {
        #if canImport(UIKit)
        if let data = provider.imageData(for: reference),
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel(altText.isEmpty ? "Image" : altText)
        } else {
            imagePlaceholder(alt: altText)
        }
        #elseif canImport(AppKit)
        if let data = provider.imageData(for: reference),
           let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel(altText.isEmpty ? "Image" : altText)
        } else {
            imagePlaceholder(alt: altText)
        }
        #endif
    }

    private func imagePlaceholder(alt: String) -> some View {
        HStack {
            Image(systemName: "photo")
                .foregroundStyle(.tertiary)
            if !alt.isEmpty {
                Text(alt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 60)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

}

// MARK: - Preview

#if DEBUG
#Preview("MarkdownDocumentView") {
    ScrollView {
        MarkdownDocumentView("""
        # Berliner Zoo
        #must-do #zoo 🦁

        ## 📍 Ort
        Hardenbergplatz 8, 10787 Berlin

        ## ⏱️ Dauer
        Ca. **2–3 Stunden**

        ## 💶 Eintritt
        - Erwachsene: 18 €
        - Kinder (4–15): 9 €

        ## ✅ Checkliste
        - [x] Tickets gebucht
        - [ ] Audioguide reservieren
        - [ ] Snacks einpacken

        ## 📝 Notizen
        > Unbedingt das Aquarium besuchen!

        Noch mehr Text hier:
        1. Eingang am Hardenbergplatz
        2. Ticket online kaufen

        ---

        Mehr infos unter [berliner-zoo.de](https://www.zoo-berlin.de)
        """, sectionsCollapsible: true)
        .padding()
    }
}
#endif

#endif
