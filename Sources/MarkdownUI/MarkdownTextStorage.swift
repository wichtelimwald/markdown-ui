//
//  MarkdownTextStorage.swift
//  AssistanceKit
//
//  NSTextStorage subclass with Markdown syntax highlighting.
//  Generalised from toogether for cross-project reuse.
//

#if canImport(UIKit)
import UIKit

// MARK: - MarkdownTextStorage

/// `NSTextStorage` subclass that applies Markdown syntax highlighting.
///
/// Uses a set of compiled `NSRegularExpression` patterns to locate Markdown
/// constructs and applies `NSAttributedString` attributes — colours, fonts,
/// and font traits — to produce live syntax highlighting with minimal overhead.
///
/// The highlighting pass runs in ``processEditing()`` after every user edit,
/// re-highlighting only the paragraph containing the edit for small inputs and
/// the full string for large ones. All work stays on the main thread to comply
/// with `NSTextStorage` threading rules.
///
/// - Important: When using `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`,
///   this class must be explicitly `nonisolated` to match `NSTextStorage`'s
///   nonisolated API (initializers, overrides, and properties).
nonisolated public final class MarkdownTextStorage: NSTextStorage {

    // MARK: Properties

    /// The colour theme used for syntax highlighting. Changing this triggers a full rehighlight.
    nonisolated(unsafe) public var theme: MarkdownTheme = .defaultLight {
        didSet { if oldValue != theme { rehighlight() } }
    }

    private nonisolated(unsafe) let store = NSMutableAttributedString()

    /// The colour scheme to use for resolving the theme appearance.
    /// Defaults to `.light`. Set to `.dark` when the host trait collection is dark.
    nonisolated(unsafe) public var colorScheme: MarkdownTheme.ColorScheme = .light {
        didSet { if oldValue != colorScheme { rehighlight() } }
    }

    /// The zero-based index of the "active" block (where the cursor is).
    ///
    /// When set to a non-nil value and ``livePreviewEnabled`` is `true`,
    /// only the active block shows raw Markdown syntax. Inactive blocks
    /// hide their control characters and render formatted text.
    ///
    /// Set to `nil` to treat all blocks as active (raw syntax everywhere).
    nonisolated(unsafe) public var activeBlockIndex: Int? {
        didSet { if oldValue != activeBlockIndex { rehighlight() } }
    }

    /// When `true`, inactive blocks hide Markdown control characters and
    /// render formatted content (Bear-style Live Preview per ADR-0004).
    /// When `false` (default), all blocks show raw syntax with highlighting.
    ///
    /// - Note: When ``proModeEnabled`` is `true`, live preview is forced off
    ///   regardless of this setting.
    nonisolated(unsafe) public var livePreviewEnabled: Bool = false {
        didSet { if oldValue != livePreviewEnabled { rehighlight() } }
    }

    /// When `true`, disables live preview and always shows raw Markdown syntax
    /// with full highlighting (Pro Mode per AK-066).
    ///
    /// Overrides ``livePreviewEnabled`` — when Pro Mode is on, all blocks
    /// show their control characters regardless of the live preview setting.
    /// Defaults to `false`.
    nonisolated(unsafe) public var proModeEnabled: Bool = false {
        didSet { if oldValue != proModeEnabled { rehighlight() } }
    }

    // MARK: Derived Colours

    private var resolvedAppearance: MarkdownTheme.Appearance {
        theme.appearance(for: colorScheme)
    }

    private var accentColor: UIColor { UIColor(markdownHex: resolvedAppearance.accentColor) ?? .systemBlue }
    private var syntaxColor: UIColor { UIColor(markdownHex: resolvedAppearance.syntaxColor) ?? .secondaryLabel }
    private var codeFgColor: UIColor { UIColor(markdownHex: resolvedAppearance.codeForeground) ?? .systemGreen }
    private var codeBgColor: UIColor {
        UIColor(markdownHex: resolvedAppearance.codeBackground) ?? .systemGreen.withAlphaComponent(0.1)
    }

    // MARK: NSTextStorage overrides

    override public var string: String { store.string }

    /// Returns the attributes for the character at the given index.
    ///
    /// - Parameters:
    ///   - location: The index of the character whose attributes are requested.
    ///   - range: On return, the range over which the attributes apply.
    /// - Returns: The attributes for the character at `location`.
    override public func attributes(
        at location: Int,
        effectiveRange range: NSRangePointer?
    ) -> [NSAttributedString.Key: Any] {
        store.attributes(at: location, effectiveRange: range)
    }

    /// Replaces characters in the given range and triggers re-highlighting.
    ///
    /// - Parameters:
    ///   - range: The range of characters to replace.
    ///   - str: The replacement string.
    override public func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        store.replaceCharacters(in: range, with: str)
        edited(.editedCharacters, range: range, changeInLength: str.utf16.count - range.length)
        endEditing()
    }

    /// Sets the attributes for the given range of characters.
    ///
    /// - Parameters:
    ///   - attrs: The attributes to apply, or `nil` to remove all attributes.
    ///   - range: The range of characters to which the attributes apply.
    override public func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        beginEditing()
        store.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }

    /// Overrides `NSTextStorage.processEditing()` to apply Markdown syntax
    /// highlighting to the paragraph range affected by the current edit.
    ///
    /// Called automatically by the text system after each editing operation.
    override public func processEditing() {
        applyHighlighting(range: editedRange.extendedToParagraphBoundaries(in: string))
        super.processEditing()
    }

    // MARK: Public API

    /// Replaces the entire content with `markdown`, triggering a full re-highlight.
    public func setMarkdownString(_ markdown: String) {
        beginEditing()
        let oldLength = store.length
        store.replaceCharacters(in: NSRange(location: 0, length: oldLength), with: markdown)
        edited(.editedCharacters, range: NSRange(location: 0, length: oldLength), changeInLength: markdown.utf16.count - oldLength)
        endEditing()
    }

    /// Re-runs the highlighting pass over the full string without modifying text content.
    public func rehighlight() {
        guard store.length > 0 else { return }
        beginEditing()
        applyHighlighting(range: NSRange(location: 0, length: store.length))
        edited(.editedAttributes, range: NSRange(location: 0, length: store.length), changeInLength: 0)
        endEditing()
    }

    // MARK: - Highlighting

    private func applyHighlighting(range: NSRange) {
        let safeRange = NSIntersectionRange(range, NSRange(location: 0, length: store.length))
        guard safeRange.length > 0 else { return }

        // Reset to base attributes over the affected range.
        store.setAttributes(baseAttributes, range: safeRange)

        // Capture theme-derived colors for use inside closures (avoids repeated property access).
        let accent   = accentColor
        let syntax   = syntaxColor
        let codeFg   = codeFgColor
        let codeBg   = codeBgColor

        // Pre-compute all fonts for the current typography + Dynamic Type setting.
        let fonts = MarkdownFontProvider(typography: theme.typography)

        // Compute block ranges for live preview mode.
        // When live preview is enabled (and Pro Mode is off), block ranges are needed
        // both when an active block is set (to render only that block as raw) and when
        // no block is active (to render all blocks as clean/formatted).
        // Pro Mode overrides live preview — all blocks show raw syntax.
        let effectiveLivePreview = livePreviewEnabled && !proModeEnabled
        let blockRanges: [NSRange]?
        if effectiveLivePreview {
            blockRanges = computeBlockLineRanges()
        } else {
            blockRanges = nil
        }

        for rule in highlightingRules {
            rule.regex.enumerateMatches(
                in: store.string,
                options: [],
                range: safeRange
            ) { match, _, _ in
                guard let match else { return }
                let matchRange = match.range

                // Determine whether this match is in the active block.
                let isInActiveBlock = isMatchInActiveBlock(matchRange, blockRanges: blockRanges)

                if isInActiveBlock {
                    // Active block (or live preview disabled): full syntax highlighting.
                    store.addAttributes(
                        rule.syntaxAttributes(accent, syntax, codeFg, codeBg, fonts),
                        range: matchRange
                    )

                    if rule.contentGroup > 0, rule.contentGroup < match.numberOfRanges {
                        let contentRange = match.range(at: rule.contentGroup)
                        if contentRange.location != NSNotFound {
                            store.addAttributes(
                                rule.contentAttributes(accent, syntax, codeFg, codeBg, fonts),
                                range: contentRange
                            )
                            // Add font traits additively (preserves heading size for bold/italic).
                            self.applyFontTraitOverride(rule.fontTraitOverride, in: contentRange)
                        }
                    }
                } else {
                    // Inactive block in live preview: apply content formatting but hide syntax.
                    if rule.contentGroup > 0, rule.contentGroup < match.numberOfRanges {
                        let contentRange = match.range(at: rule.contentGroup)
                        if contentRange.location != NSNotFound {
                            // Apply semantic formatting to content (bold, italic, heading size, etc.)
                            store.addAttributes(
                                rule.contentAttributes(accent, syntax, codeFg, codeBg, fonts),
                                range: contentRange
                            )
                            // Add font traits additively (preserves heading size for bold/italic).
                            self.applyFontTraitOverride(rule.fontTraitOverride, in: contentRange)
                        }
                    }

                    // Hide syntax characters by making them transparent + near-zero size.
                    hideSyntaxCharacters(in: match, contentGroup: rule.contentGroup)
                }
            }
        }
    }

    /// Determines whether a match is in the active block (or if live preview is off).
    ///
    /// When live preview is enabled and no block is active (cursor not in the editor),
    /// all blocks are treated as inactive so they render in their clean, formatted form.
    private func isMatchInActiveBlock(_ matchRange: NSRange, blockRanges: [NSRange]?) -> Bool {
        guard let blockRanges else { return true }
        // No active block → return false so all blocks render as inactive (clean view).
        guard let activeIdx = activeBlockIndex else { return false }
        guard activeIdx >= 0, activeIdx < blockRanges.count else { return true }
        let activeRange = blockRanges[activeIdx]
        return NSIntersectionRange(matchRange, activeRange).length > 0
    }

    /// Adds font traits additively to the existing font in a range.
    ///
    /// When `traits` is non-nil, enumerates the `.font` attribute in the given range
    /// and unions the specified traits with each font's existing symbolic traits.
    /// This preserves the font's point size (e.g. heading sizes) while adding
    /// bold or italic emphasis.
    ///
    /// - Parameters:
    ///   - traits: The symbolic traits to add, or `nil` to do nothing.
    ///   - range: The range in which to modify fonts.
    private func applyFontTraitOverride(_ traits: UIFontDescriptor.SymbolicTraits?, in range: NSRange) {
        guard let traits else { return }
        store.enumerateAttribute(.font, in: range, options: []) { value, attrRange, _ in
            if let existingFont = value as? UIFont {
                let modifiedFont = existingFont.markdownAddingTraits(traits)
                store.addAttribute(.font, value: modifiedFont, range: attrRange)
            }
        }
    }

    /// Font size used to visually hide Markdown syntax characters in live preview mode.
    /// Near-zero to minimize layout impact while keeping the text storage valid.
    private static let hiddenSyntaxFontSize: CGFloat = 0.01

    /// Hides the syntax/control characters in a regex match by setting them to
    /// transparent foreground and near-zero font size.
    ///
    /// For a match like `**bold text**` with contentGroup=2, the syntax chars
    /// are group 1 (`**`) and group 3 (`**`), and the content group 2 is left visible.
    /// For a match with contentGroup=0, we hide nothing (the whole match is "content").
    private func hideSyntaxCharacters(in match: NSTextCheckingResult, contentGroup: Int) {
        guard contentGroup > 0 else { return }

        let hiddenAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.clear,
            .font: UIFont.systemFont(ofSize: Self.hiddenSyntaxFontSize),
        ]

        // Hide all groups that are not the content group.
        for group in 0..<match.numberOfRanges {
            if group == contentGroup { continue }
            if group == 0 { continue } // group 0 is the full match
            let groupRange = match.range(at: group)
            if groupRange.location != NSNotFound, groupRange.length > 0 {
                store.addAttributes(hiddenAttrs, range: groupRange)
            }
        }

        // If contentGroup is the only capture group (e.g. pattern has no explicit
        // syntax groups like `^(#{1})\s(.+)$`), hide the syntax portion manually.
        // For headings: group 1 = `#`, group 2 = content text.
        // The loop above already handles this since group 1 != contentGroup 2.

        // Special case: for patterns where the full match includes syntax chars
        // not captured in groups (e.g. `*text*` where `*` isn't in a group),
        // hide the ranges between the full match and the content group.
        let fullRange = match.range
        let contentRange = match.range(at: contentGroup)
        guard contentRange.location != NSNotFound else { return }

        // Before content: syntax chars from match start to content start
        let beforeLen = contentRange.location - fullRange.location
        if beforeLen > 0 {
            let beforeRange = NSRange(location: fullRange.location, length: beforeLen)
            store.addAttributes(hiddenAttrs, range: beforeRange)
        }

        // After content: syntax chars from content end to match end
        let contentEnd = contentRange.location + contentRange.length
        let fullEnd = fullRange.location + fullRange.length
        let afterLen = fullEnd - contentEnd
        if afterLen > 0 {
            let afterRange = NSRange(location: contentEnd, length: afterLen)
            store.addAttributes(hiddenAttrs, range: afterRange)
        }
    }

    /// Computes the character ranges for each block produced by ``MarkdownBlockParser``.
    ///
    /// Returns an array of `NSRange` values, one per block, mapping each block to its
    /// character range in the stored string. This is computed on demand during highlighting
    /// for live preview mode.
    private func computeBlockLineRanges() -> [NSRange] {
        let text = store.string
        guard !text.isEmpty else { return [] }

        let lines = text.components(separatedBy: "\n")
        var lineStartOffsets: [Int] = []
        var pos = 0
        for line in lines {
            lineStartOffsets.append(pos)
            pos += (line as NSString).length + 1 // +1 for newline
        }

        // Walk lines with the same logic as MarkdownBlockParser.parse() to compute
        // the start line of each block.
        var blockStartLines: [Int] = []
        var inParagraph = false
        var lastWasBlank = false
        var blockCount = 0

        for (lineIdx, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Heading
            if line.hasPrefix("### ") || line.hasPrefix("## ") || line.hasPrefix("# ") {
                if inParagraph { blockCount += 1; inParagraph = false }
                blockStartLines.append(lineIdx)
                blockCount += 1
                lastWasBlank = false
                continue
            }

            // Horizontal rule
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                if inParagraph { blockCount += 1; inParagraph = false }
                blockStartLines.append(lineIdx)
                blockCount += 1
                lastWasBlank = false
                continue
            }

            // Image
            if MarkdownBlockParser.isImageLine(line) {
                if inParagraph { blockCount += 1; inParagraph = false }
                blockStartLines.append(lineIdx)
                blockCount += 1
                lastWasBlank = false
                continue
            }

            // Blockquote
            if line.hasPrefix("> ") || (line.hasPrefix(">") && line.count > 1) {
                if inParagraph { blockCount += 1; inParagraph = false }
                blockStartLines.append(lineIdx)
                blockCount += 1
                lastWasBlank = false
                continue
            }

            // Task list
            if MarkdownBlockParser.isTaskListLine(line) {
                if inParagraph { blockCount += 1; inParagraph = false }
                blockStartLines.append(lineIdx)
                blockCount += 1
                lastWasBlank = false
                continue
            }

            // Unordered list
            if MarkdownBlockParser.isUnorderedListLine(line) {
                if inParagraph { blockCount += 1; inParagraph = false }
                blockStartLines.append(lineIdx)
                blockCount += 1
                lastWasBlank = false
                continue
            }

            // Ordered list
            if MarkdownBlockParser.isOrderedListLine(line) {
                if inParagraph { blockCount += 1; inParagraph = false }
                blockStartLines.append(lineIdx)
                blockCount += 1
                lastWasBlank = false
                continue
            }

            // Blank
            if trimmed.isEmpty {
                if inParagraph { blockCount += 1; inParagraph = false }
                if !lastWasBlank && blockCount > 0 {
                    blockStartLines.append(lineIdx)
                    blockCount += 1
                    lastWasBlank = true
                }
                continue
            }
            lastWasBlank = false

            // Tag line (skipped)
            if MarkdownBlockParser.isTagLine(line) {
                if inParagraph { blockCount += 1; inParagraph = false }
                continue
            }

            // Paragraph
            if !inParagraph {
                blockStartLines.append(lineIdx)
                inParagraph = true
            }
        }

        // Convert block start lines to NSRange
        var ranges: [NSRange] = []
        let totalLength = (text as NSString).length

        for (i, startLine) in blockStartLines.enumerated() {
            let startOffset = lineStartOffsets[startLine]
            let endOffset: Int
            if i + 1 < blockStartLines.count {
                endOffset = lineStartOffsets[blockStartLines[i + 1]]
            } else {
                endOffset = totalLength
            }
            let length = max(0, endOffset - startOffset)
            ranges.append(NSRange(location: startOffset, length: length))
        }

        return ranges
    }

    // MARK: - Base Attributes

    private var baseAttributes: [NSAttributedString.Key: Any] {
        let fonts = MarkdownFontProvider(typography: theme.typography)
        return [
            .font: fonts.body,
            .foregroundColor: UIColor.label,
        ]
    }

    // MARK: - Highlighting Rules

    /// Compiled Markdown syntax-highlighting patterns.
    ///
    /// `nonisolated(unsafe)` is required because `[HighlightingRule]` contains
    /// non-Sendable closures, and the class is `nonisolated`. The property is
    /// safe: it is a `let` assigned once at init time and never mutated.
    /// `lazy var` cannot be used because Swift does not support `nonisolated`
    /// on lazy properties.
    // swiftlint:disable:next identifier_name
    private nonisolated(unsafe) let highlightingRules: [HighlightingRule] = MarkdownTextStorage.buildRules()

    private static func buildRules() -> [HighlightingRule] {
        var rules: [HighlightingRule] = []

        // H1 — # Heading
        rules.append(HighlightingRule(
            pattern: #"^(#{1})\s(.+)$"#,
            options: [.anchorsMatchLines],
            syntaxAttrs: { accent, _, _, _, fonts in [
                .foregroundColor: accent.withAlphaComponent(0.5),
                .font: fonts.title1Bold,
            ]},
            contentGroup: 2,
            contentAttrs: { _, _, _, _, fonts in [
                .font: fonts.title1Bold,
                .foregroundColor: UIColor.label,
            ]}
        ))

        // H2 — ## Heading
        rules.append(HighlightingRule(
            pattern: #"^(#{2})\s(.+)$"#,
            options: [.anchorsMatchLines],
            syntaxAttrs: { accent, _, _, _, fonts in [
                .foregroundColor: accent.withAlphaComponent(0.5),
                .font: fonts.title2Bold,
            ]},
            contentGroup: 2,
            contentAttrs: { _, _, _, _, fonts in [
                .font: fonts.title2Bold,
                .foregroundColor: UIColor.label,
            ]}
        ))

        // H3 — ### Heading
        rules.append(HighlightingRule(
            pattern: #"^(#{3})\s(.+)$"#,
            options: [.anchorsMatchLines],
            syntaxAttrs: { accent, _, _, _, fonts in [
                .foregroundColor: accent.withAlphaComponent(0.5),
                .font: fonts.title3Bold,
            ]},
            contentGroup: 2,
            contentAttrs: { _, _, _, _, fonts in [
                .font: fonts.title3Bold,
                .foregroundColor: UIColor.label,
            ]}
        ))

        // Bold — **text** or __text__
        rules.append(HighlightingRule(
            pattern: #"(\*\*|__)(.+?)(\*\*|__)"#,
            syntaxAttrs: { accent, _, _, _, _ in [.foregroundColor: accent.withAlphaComponent(0.4)] },
            contentGroup: 2,
            contentAttrs: { _, _, _, _, _ in [
                .foregroundColor: UIColor.label,
            ] },
            fontTraitOverride: .traitBold
        ))

        // Italic — *text* (asterisk variant)
        rules.append(HighlightingRule(
            pattern: #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#,
            syntaxAttrs: { accent, _, _, _, _ in [.foregroundColor: accent.withAlphaComponent(0.4)] },
            contentGroup: 1,
            contentAttrs: { _, _, _, _, _ in [
                .foregroundColor: UIColor.label,
            ] },
            fontTraitOverride: .traitItalic
        ))

        // Italic — _text_ (underscore variant)
        rules.append(HighlightingRule(
            pattern: #"(?<!_)_(?!_)(.+?)(?<!_)_(?!_)"#,
            syntaxAttrs: { accent, _, _, _, _ in [.foregroundColor: accent.withAlphaComponent(0.4)] },
            contentGroup: 1,
            contentAttrs: { _, _, _, _, _ in [
                .foregroundColor: UIColor.label,
            ] },
            fontTraitOverride: .traitItalic
        ))

        // Strikethrough — ~~text~~
        rules.append(HighlightingRule(
            pattern: #"(~~)(.+?)(~~)"#,
            syntaxAttrs: { _, syntax, _, _, _ in [.foregroundColor: syntax] },
            contentGroup: 2,
            contentAttrs: { _, syntax, _, _, _ in [.strikethroughStyle: NSUnderlineStyle.single.rawValue,
                                                .foregroundColor: syntax] }
        ))

        // Inline code — `code`
        rules.append(HighlightingRule(
            pattern: #"(`+)(.+?)(\1)"#,
            syntaxAttrs: { _, syntax, _, _, _ in [.foregroundColor: syntax] },
            contentGroup: 2,
            contentAttrs: { _, _, codeFg, codeBg, fonts in [
                .font: fonts.code,
                .foregroundColor: codeFg,
                .backgroundColor: codeBg,
            ]}
        ))

        // Fenced code block — ```\ncode\n```
        rules.append(HighlightingRule(
            pattern: #"(`{3,})[\s\S]*?\1"#,
            options: [],
            syntaxAttrs: { _, _, codeFg, codeBg, fonts in [
                .font: fonts.code,
                .foregroundColor: codeFg,
                .backgroundColor: codeBg,
            ]},
            contentGroup: 0,
            contentAttrs: { _, _, _, _, _ in [:] }
        ))

        // Link — [text](url)
        rules.append(HighlightingRule(
            pattern: #"(!?\[)([^\]]+)(\]\([^\)]+\))"#,
            syntaxAttrs: { accent, _, _, _, _ in [.foregroundColor: accent.withAlphaComponent(0.4)] },
            contentGroup: 2,
            contentAttrs: { accent, _, _, _, _ in [.foregroundColor: accent] }
        ))

        // Unordered list item — - item or * item
        rules.append(HighlightingRule(
            pattern: #"^(\s*[-*])\s"#,
            options: [.anchorsMatchLines],
            syntaxAttrs: { accent, _, _, _, _ in [.foregroundColor: accent] },
            contentGroup: 0,
            contentAttrs: { _, _, _, _, _ in [:] }
        ))

        // Ordered list item — 1. item
        rules.append(HighlightingRule(
            pattern: #"^(\s*\d+\.)\s"#,
            options: [.anchorsMatchLines],
            syntaxAttrs: { accent, _, _, _, _ in [.foregroundColor: accent] },
            contentGroup: 0,
            contentAttrs: { _, _, _, _, _ in [:] }
        ))

        // Task list — - [ ] or - [x]
        rules.append(HighlightingRule(
            pattern: #"^(\s*[-*]\s\[[ xX]\])\s"#,
            options: [.anchorsMatchLines],
            syntaxAttrs: { accent, _, _, _, _ in [.foregroundColor: accent] },
            contentGroup: 0,
            contentAttrs: { _, _, _, _, _ in [:] }
        ))

        // Blockquote — > text
        rules.append(HighlightingRule(
            pattern: #"^(>+)\s(.+)$"#,
            options: [.anchorsMatchLines],
            syntaxAttrs: { _, syntax, _, _, _ in [.foregroundColor: syntax] },
            contentGroup: 2,
            contentAttrs: { _, _, _, _, _ in [.foregroundColor: UIColor.secondaryLabel] }
        ))

        // Horizontal rule — --- or ***
        rules.append(HighlightingRule(
            pattern: #"^([-*]{3,})$"#,
            options: [.anchorsMatchLines],
            syntaxAttrs: { _, syntax, _, _, _ in [.foregroundColor: syntax] },
            contentGroup: 0,
            contentAttrs: { _, _, _, _, _ in [:] }
        ))

        // Tag — #tagname (must start with a letter; not at line start followed by space = heading)
        rules.append(HighlightingRule(
            pattern: #"(?:^|(?<=\s))#[a-zA-ZäöüÄÖÜß][a-zA-Z0-9äöüÄÖÜß_-]*"#,
            options: [.anchorsMatchLines],
            syntaxAttrs: { accent, _, _, _, _ in [.foregroundColor: accent] },
            contentGroup: 0,
            contentAttrs: { _, _, _, _, _ in [:] }
        ))

        return rules
    }
}

// MARK: - MarkdownFontProvider

/// Pre-computed font set for Markdown syntax highlighting.
///
/// When ``MarkdownTheme/Typography/usesDynamicType`` is `true`, fonts are
/// created using `UIFont.preferredFont(forTextStyle:)` — automatically
/// respecting the current `UIContentSizeCategory`. When `false`, fonts use
/// the exact sizes specified in the theme's typography settings.
///
/// A new provider should be created each time highlighting runs, so that
/// Dynamic Type changes are picked up immediately.
nonisolated struct MarkdownFontProvider {

    let body: UIFont
    let bodyBold: UIFont
    let bodyItalic: UIFont
    let title1Bold: UIFont
    let title2Bold: UIFont
    let title3Bold: UIFont
    let code: UIFont

    init(typography: MarkdownTheme.Typography) {
        if typography.usesDynamicType {
            // Dynamic Type: use UIFont.preferredFont which respects the
            // current UIContentSizeCategory automatically.
            body = UIFont.preferredFont(forTextStyle: .body)
            bodyBold = UIFont.preferredFont(forTextStyle: .body).markdownBold()
            bodyItalic = UIFont.preferredFont(forTextStyle: .body).markdownItalic()
            title1Bold = UIFont.preferredFont(forTextStyle: .title1).markdownBold()
            title2Bold = UIFont.preferredFont(forTextStyle: .title2).markdownBold()
            title3Bold = UIFont.preferredFont(forTextStyle: .title3).markdownBold()
            code = UIFont.monospacedSystemFont(
                ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize - 1,
                weight: .regular
            )
        } else {
            // Fixed sizes: use the theme's exact bodyFontSize and headingScale.
            let baseSize = typography.bodyFontSize
            let h1Size = baseSize * typography.headingScale
            let h2Size = baseSize * typography.headingScale * 0.85
            let h3Size = baseSize * typography.headingScale * 0.7

            body = UIFont.systemFont(ofSize: baseSize)
            bodyBold = UIFont.boldSystemFont(ofSize: baseSize)
            bodyItalic = UIFont.italicSystemFont(ofSize: baseSize)
            title1Bold = UIFont.boldSystemFont(ofSize: h1Size)
            title2Bold = UIFont.boldSystemFont(ofSize: h2Size)
            title3Bold = UIFont.boldSystemFont(ofSize: h3Size)
            code = UIFont.monospacedSystemFont(ofSize: baseSize - 1, weight: .regular)
        }
    }
}

// MARK: - HighlightingRule

/// Encapsulates a single Markdown syntax highlighting pattern.
private nonisolated struct HighlightingRule {
    typealias ThemeAttrs = (
        _ accent:   UIColor,
        _ syntax:   UIColor,
        _ codeFg:   UIColor,
        _ codeBg:   UIColor,
        _ fonts:    MarkdownFontProvider
    ) -> [NSAttributedString.Key: Any]

    let regex: NSRegularExpression
    let syntaxAttrs: ThemeAttrs
    let contentGroup: Int
    let contentAttrs: ThemeAttrs

    /// When non-nil, the highlighting engine adds these font traits to the
    /// existing font instead of replacing it. This preserves heading font
    /// sizes when bold or italic appears inside a heading.
    let fontTraitOverride: UIFontDescriptor.SymbolicTraits?

    init(
        pattern: String,
        options: NSRegularExpression.Options = [],
        syntaxAttrs: @escaping ThemeAttrs,
        contentGroup: Int = 0,
        contentAttrs: @escaping ThemeAttrs = { _, _, _, _, _ in [:] },
        fontTraitOverride: UIFontDescriptor.SymbolicTraits? = nil
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            preconditionFailure("MarkdownTextStorage: invalid highlighting regex pattern — \(pattern)")
        }
        self.regex = regex
        self.syntaxAttrs = syntaxAttrs
        self.contentGroup = contentGroup
        self.contentAttrs = contentAttrs
        self.fontTraitOverride = fontTraitOverride
    }

    func syntaxAttributes(
        _ accent: UIColor, _ syntax: UIColor, _ codeFg: UIColor, _ codeBg: UIColor,
        _ fonts: MarkdownFontProvider
    ) -> [NSAttributedString.Key: Any] {
        syntaxAttrs(accent, syntax, codeFg, codeBg, fonts)
    }

    func contentAttributes(
        _ accent: UIColor, _ syntax: UIColor, _ codeFg: UIColor, _ codeBg: UIColor,
        _ fonts: MarkdownFontProvider
    ) -> [NSAttributedString.Key: Any] {
        contentAttrs(accent, syntax, codeFg, codeBg, fonts)
    }
}

// MARK: - UIColor + Markdown Hex

nonisolated extension UIColor {
    /// Creates a `UIColor` from a CSS hex string (e.g. `"#FF5722"` or `"FF5722"`).
    ///
    /// Supports 3-digit (`#RGB`) and 6-digit (`#RRGGBB`) hex strings.
    /// Returns `nil` for malformed inputs.
    ///
    /// - Note: Named `markdownHex` to avoid collisions with app-level extensions.
    convenience init?(markdownHex hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }

        // Expand 3-digit shorthand (#RGB → #RRGGBB)
        if cleaned.count == 3 {
            cleaned = cleaned.map { "\($0)\($0)" }.joined()
        }

        guard cleaned.count == 6,
              let value = UInt64(cleaned, radix: 16) else { return nil }

        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >>  8) & 0xFF) / 255
        let b = CGFloat( value        & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

// MARK: - NSRange helpers

private nonisolated extension NSRange {
    /// Expands the range to include complete paragraphs for line-by-line rules.
    func extendedToParagraphBoundaries(in string: String) -> NSRange {
        let nsString = string as NSString
        guard nsString.length > 0 else { return self }
        let safe = NSIntersectionRange(self, NSRange(location: 0, length: nsString.length))
        return nsString.paragraphRange(for: safe)
    }
}

// MARK: - UIFont helpers

nonisolated extension UIFont {
    /// Returns a bold variant of this font.
    func markdownBold() -> UIFont {
        markdownWithTraits(.traitBold)
    }

    /// Returns an italic variant of this font.
    func markdownItalic() -> UIFont {
        markdownWithTraits(.traitItalic)
    }

    /// Returns a variant of this font with the given traits added to the existing ones.
    ///
    /// Unlike ``markdownBold()`` / ``markdownItalic()`` which replace traits,
    /// this method unions the new traits with the font's current traits.
    /// For example, adding `.traitItalic` to a bold heading preserves both
    /// bold and italic while keeping the heading's point size.
    func markdownAddingTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        let merged = fontDescriptor.symbolicTraits.union(traits)
        guard let descriptor = fontDescriptor.withSymbolicTraits(merged) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }

    private func markdownWithTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }
}

#endif
