import Testing
import Foundation

// MARK: - MarkdownTextStorage Regex Pattern Tests

/// Tests every regex pattern used by `MarkdownTextStorage` for syntax highlighting.
///
/// Because `MarkdownTextStorage` is UIKit-only (`#if canImport(UIKit)`), these tests
/// validate the regex patterns directly via `NSRegularExpression` so they can run on
/// any platform (including Linux CI).
///
/// Each test verifies:
/// 1. The pattern compiles without error.
/// 2. Positive cases: expected Markdown constructs match.
/// 3. Negative cases: non-matching input does not match.
/// 4. Capture groups extract the expected content.
@Suite("MarkdownTextStorage Regex Pattern Tests")
struct MarkdownTextStorageTests {

    // MARK: - Helpers

    /// Compiles a regex pattern and returns all matches in the input string.
    private func matches(
        pattern: String,
        options: NSRegularExpression.Options = [],
        in input: String
    ) -> [NSTextCheckingResult] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return []
        }
        return regex.matches(in: input, range: NSRange(input.startIndex..., in: input))
    }

    /// Returns the matched substring for a given capture group.
    private func captureGroup(
        _ group: Int,
        in match: NSTextCheckingResult,
        string: String
    ) -> String? {
        guard group < match.numberOfRanges else { return nil }
        let range = match.range(at: group)
        guard range.location != NSNotFound,
              let swiftRange = Range(range, in: string) else { return nil }
        return String(string[swiftRange])
    }

    // MARK: - H1 — # Heading

    @Test("H1 pattern matches single-hash heading")
    func h1Matches() {
        let pattern = #"^(#{1})\s(.+)$"#
        let input = "# My Title"
        let result = matches(pattern: pattern, options: [.anchorsMatchLines], in: input)
        #expect(result.count == 1)
        #expect(captureGroup(1, in: result[0], string: input) == "#")
        #expect(captureGroup(2, in: result[0], string: input) == "My Title")
    }

    @Test("H1 pattern does not match H2 or H3")
    func h1NoMatchH2H3() {
        let pattern = #"^(#{1})\s(.+)$"#
        let h2 = "## Not H1"
        let h3 = "### Not H1"
        #expect(matches(pattern: pattern, options: [.anchorsMatchLines], in: h2).isEmpty)
        #expect(matches(pattern: pattern, options: [.anchorsMatchLines], in: h3).isEmpty)
    }

    @Test("H1 pattern does not match without space")
    func h1NoMatchNoSpace() {
        let pattern = #"^(#{1})\s(.+)$"#
        #expect(matches(pattern: pattern, options: [.anchorsMatchLines], in: "#NoSpace").isEmpty)
    }

    // MARK: - H2 — ## Heading

    @Test("H2 pattern matches double-hash heading")
    func h2Matches() {
        let pattern = #"^(#{2})\s(.+)$"#
        let input = "## Section"
        let result = matches(pattern: pattern, options: [.anchorsMatchLines], in: input)
        #expect(result.count == 1)
        #expect(captureGroup(1, in: result[0], string: input) == "##")
        #expect(captureGroup(2, in: result[0], string: input) == "Section")
    }

    @Test("H2 pattern does not match H1 or H3")
    func h2NoMatchH1H3() {
        let pattern = #"^(#{2})\s(.+)$"#
        #expect(matches(pattern: pattern, options: [.anchorsMatchLines], in: "# Not H2").isEmpty)
        #expect(matches(pattern: pattern, options: [.anchorsMatchLines], in: "### Not H2").isEmpty)
    }

    // MARK: - H3 — ### Heading

    @Test("H3 pattern matches triple-hash heading")
    func h3Matches() {
        let pattern = #"^(#{3})\s(.+)$"#
        let input = "### Subsection"
        let result = matches(pattern: pattern, options: [.anchorsMatchLines], in: input)
        #expect(result.count == 1)
        #expect(captureGroup(2, in: result[0], string: input) == "Subsection")
    }

    @Test("H3 pattern does not match H1 or H2")
    func h3NoMatchH1H2() {
        let pattern = #"^(#{3})\s(.+)$"#
        #expect(matches(pattern: pattern, options: [.anchorsMatchLines], in: "# Not").isEmpty)
        #expect(matches(pattern: pattern, options: [.anchorsMatchLines], in: "## Not").isEmpty)
    }

    // MARK: - Headings in multi-line text

    @Test("Heading patterns match correct lines in multi-line text")
    func headingsMultiLine() {
        let input = "# Title\n## Section\n### Sub\nParagraph text"
        let h1 = matches(pattern: #"^(#{1})\s(.+)$"#, options: [.anchorsMatchLines], in: input)
        let h2 = matches(pattern: #"^(#{2})\s(.+)$"#, options: [.anchorsMatchLines], in: input)
        let h3 = matches(pattern: #"^(#{3})\s(.+)$"#, options: [.anchorsMatchLines], in: input)
        #expect(h1.count == 1)
        #expect(h2.count == 1)
        #expect(h3.count == 1)
        #expect(captureGroup(2, in: h1[0], string: input) == "Title")
        #expect(captureGroup(2, in: h2[0], string: input) == "Section")
        #expect(captureGroup(2, in: h3[0], string: input) == "Sub")
    }

    @Test("Heading with emoji")
    func headingEmoji() {
        let input = "## 📍 Ort / Location"
        let result = matches(pattern: #"^(#{2})\s(.+)$"#, options: [.anchorsMatchLines], in: input)
        #expect(result.count == 1)
        #expect(captureGroup(2, in: result[0], string: input) == "📍 Ort / Location")
    }

    // MARK: - Bold — **text** or __text__

    @Test("Bold pattern matches **text**")
    func boldAsterisks() {
        let pattern = #"(\*\*|__)(.+?)(\*\*|__)"#
        let input = "Some **bold** text"
        let result = matches(pattern: pattern, in: input)
        #expect(result.count == 1)
        #expect(captureGroup(2, in: result[0], string: input) == "bold")
    }

    @Test("Bold pattern matches __text__")
    func boldUnderscores() {
        let pattern = #"(\*\*|__)(.+?)(\*\*|__)"#
        let input = "Some __bold__ text"
        let result = matches(pattern: pattern, in: input)
        #expect(result.count == 1)
        #expect(captureGroup(2, in: result[0], string: input) == "bold")
    }

    @Test("Bold pattern matches multiple bold spans")
    func boldMultiple() {
        let pattern = #"(\*\*|__)(.+?)(\*\*|__)"#
        let input = "**first** and **second**"
        let result = matches(pattern: pattern, in: input)
        #expect(result.count == 2)
    }

    @Test("Bold pattern does not match single asterisk")
    func boldNoSingleAsterisk() {
        let pattern = #"(\*\*|__)(.+?)(\*\*|__)"#
        #expect(matches(pattern: pattern, in: "*not bold*").isEmpty)
    }

    // MARK: - Italic (asterisk) — *text*

    @Test("Italic asterisk pattern matches *text*")
    func italicAsterisk() {
        let pattern = #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#
        let input = "Some *italic* text"
        let result = matches(pattern: pattern, in: input)
        #expect(result.count == 1)
        #expect(captureGroup(1, in: result[0], string: input) == "italic")
    }

    @Test("Italic asterisk does not match **bold**")
    func italicAsteriskNoBold() {
        let pattern = #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#
        let input = "**bold**"
        // The pattern uses lookbehind/lookahead to exclude **
        let result = matches(pattern: pattern, in: input)
        // Inside **bold**, the inner * characters are adjacent to other *
        #expect(result.isEmpty)
    }

    // MARK: - Italic (underscore) — _text_

    @Test("Italic underscore pattern matches _text_")
    func italicUnderscore() {
        let pattern = #"(?<!_)_(?!_)(.+?)(?<!_)_(?!_)"#
        let input = "Some _italic_ text"
        let result = matches(pattern: pattern, in: input)
        #expect(result.count == 1)
        #expect(captureGroup(1, in: result[0], string: input) == "italic")
    }

    @Test("Italic underscore does not match __bold__")
    func italicUnderscoreNoBold() {
        let pattern = #"(?<!_)_(?!_)(.+?)(?<!_)_(?!_)"#
        let input = "__bold__"
        let result = matches(pattern: pattern, in: input)
        #expect(result.isEmpty)
    }

    // MARK: - Strikethrough — ~~text~~

    @Test("Strikethrough pattern matches ~~text~~")
    func strikethroughMatches() {
        let pattern = #"(~~)(.+?)(~~)"#
        let input = "Some ~~deleted~~ text"
        let result = matches(pattern: pattern, in: input)
        #expect(result.count == 1)
        #expect(captureGroup(2, in: result[0], string: input) == "deleted")
    }

    @Test("Strikethrough does not match single tilde")
    func strikethroughNoSingle() {
        let pattern = #"(~~)(.+?)(~~)"#
        #expect(matches(pattern: pattern, in: "~not~").isEmpty)
    }

    // MARK: - Inline code — `code`

    @Test("Inline code pattern matches `code`")
    func inlineCodeMatches() {
        let pattern = #"(`+)(.+?)(\1)"#
        let input = "Some `inline code` here"
        let result = matches(pattern: pattern, in: input)
        #expect(result.count == 1)
        #expect(captureGroup(2, in: result[0], string: input) == "inline code")
    }

    @Test("Inline code with double backticks")
    func inlineCodeDouble() {
        let pattern = #"(`+)(.+?)(\1)"#
        let input = "Use ``let x = 1`` here"
        let result = matches(pattern: pattern, in: input)
        #expect(result.count == 1)
        #expect(captureGroup(2, in: result[0], string: input) == "let x = 1")
    }

    @Test("Inline code does not match empty backticks")
    func inlineCodeNoEmpty() {
        let pattern = #"(`+)(.+?)(\1)"#
        #expect(matches(pattern: pattern, in: "``").isEmpty)
    }

    // MARK: - Fenced code block — ```code```

    @Test("Fenced code block pattern matches triple backticks")
    func fencedCodeMatches() {
        let pattern = #"(`{3,})[\s\S]*?\1"#
        let input = "```\nlet x = 1\nlet y = 2\n```"
        let result = matches(pattern: pattern, in: input)
        #expect(result.count == 1)
    }

    @Test("Fenced code block with language identifier")
    func fencedCodeLanguage() {
        let pattern = #"(`{3,})[\s\S]*?\1"#
        let input = "```swift\nlet x = 1\n```"
        let result = matches(pattern: pattern, in: input)
        #expect(result.count == 1)
    }

    @Test("Fenced code block does not match single backtick")
    func fencedCodeNoSingle() {
        let pattern = #"(`{3,})[\s\S]*?\1"#
        #expect(matches(pattern: pattern, in: "`code`").isEmpty)
    }

    // MARK: - Link — [text](url)

    @Test("Link pattern matches [text](url)")
    func linkMatches() {
        let pattern = #"(!?\[)([^\]]+)(\]\([^\)]+\))"#
        let input = "Visit [Google](https://google.com) today"
        let result = matches(pattern: pattern, in: input)
        #expect(result.count == 1)
        #expect(captureGroup(2, in: result[0], string: input) == "Google")
    }

    @Test("Link pattern matches image links ![alt](url)")
    func imageLinkMatches() {
        let pattern = #"(!?\[)([^\]]+)(\]\([^\)]+\))"#
        let input = "![Photo](https://example.com/img.jpg)"
        let result = matches(pattern: pattern, in: input)
        #expect(result.count == 1)
        #expect(captureGroup(2, in: result[0], string: input) == "Photo")
    }

    @Test("Link pattern does not match empty brackets")
    func linkNoEmpty() {
        let pattern = #"(!?\[)([^\]]+)(\]\([^\)]+\))"#
        #expect(matches(pattern: pattern, in: "[](https://example.com)").isEmpty)
    }

    // MARK: - Unordered list — - item or * item

    @Test("Unordered list pattern matches dash")
    func unorderedListDash() {
        let pattern = #"^(\s*[-*])\s"#
        let input = "- Item one"
        let result = matches(pattern: pattern, options: [.anchorsMatchLines], in: input)
        #expect(result.count == 1)
        #expect(captureGroup(1, in: result[0], string: input) == "-")
    }

    @Test("Unordered list pattern matches asterisk")
    func unorderedListAsterisk() {
        let pattern = #"^(\s*[-*])\s"#
        let input = "* Item one"
        let result = matches(pattern: pattern, options: [.anchorsMatchLines], in: input)
        #expect(result.count == 1)
    }

    @Test("Unordered list pattern matches nested with indentation")
    func unorderedListNested() {
        let pattern = #"^(\s*[-*])\s"#
        let input = "  - Nested item"
        let result = matches(pattern: pattern, options: [.anchorsMatchLines], in: input)
        #expect(result.count == 1)
        #expect(captureGroup(1, in: result[0], string: input) == "  -")
    }

    @Test("Unordered list pattern does not match mid-line dash")
    func unorderedListNoMidLine() {
        let pattern = #"^(\s*[-*])\s"#
        #expect(matches(pattern: pattern, options: [.anchorsMatchLines], in: "Some - text").isEmpty)
    }

    // MARK: - Ordered list — 1. item

    @Test("Ordered list pattern matches numbered items")
    func orderedListMatches() {
        let pattern = #"^(\s*\d+\.)\s"#
        let input = "1. First item"
        let result = matches(pattern: pattern, options: [.anchorsMatchLines], in: input)
        #expect(result.count == 1)
        #expect(captureGroup(1, in: result[0], string: input) == "1.")
    }

    @Test("Ordered list pattern matches multi-digit numbers")
    func orderedListMultiDigit() {
        let pattern = #"^(\s*\d+\.)\s"#
        let input = "42. Answer"
        let result = matches(pattern: pattern, options: [.anchorsMatchLines], in: input)
        #expect(result.count == 1)
        #expect(captureGroup(1, in: result[0], string: input) == "42.")
    }

    @Test("Ordered list pattern does not match mid-line numbers")
    func orderedListNoMidLine() {
        let pattern = #"^(\s*\d+\.)\s"#
        #expect(matches(pattern: pattern, options: [.anchorsMatchLines], in: "See item 1. here").isEmpty)
    }

    // MARK: - Task list — - [ ] or - [x]

    @Test("Task list pattern matches unchecked item")
    func taskListUnchecked() {
        let pattern = #"^(\s*[-*]\s\[[ xX]\])\s"#
        let input = "- [ ] Todo item"
        let result = matches(pattern: pattern, options: [.anchorsMatchLines], in: input)
        #expect(result.count == 1)
        #expect(captureGroup(1, in: result[0], string: input) == "- [ ]")
    }

    @Test("Task list pattern matches checked item (lowercase x)")
    func taskListCheckedLower() {
        let pattern = #"^(\s*[-*]\s\[[ xX]\])\s"#
        let input = "- [x] Done"
        let result = matches(pattern: pattern, options: [.anchorsMatchLines], in: input)
        #expect(result.count == 1)
        #expect(captureGroup(1, in: result[0], string: input) == "- [x]")
    }

    @Test("Task list pattern matches checked item (uppercase X)")
    func taskListCheckedUpper() {
        let pattern = #"^(\s*[-*]\s\[[ xX]\])\s"#
        let input = "- [X] Done"
        let result = matches(pattern: pattern, options: [.anchorsMatchLines], in: input)
        #expect(result.count == 1)
    }

    @Test("Task list with asterisk marker")
    func taskListAsterisk() {
        let pattern = #"^(\s*[-*]\s\[[ xX]\])\s"#
        let input = "* [ ] Todo"
        let result = matches(pattern: pattern, options: [.anchorsMatchLines], in: input)
        #expect(result.count == 1)
    }

    @Test("Task list does not match without space after bracket")
    func taskListNoSpaceAfter() {
        let pattern = #"^(\s*[-*]\s\[[ xX]\])\s"#
        // Missing trailing space after ]
        #expect(matches(pattern: pattern, options: [.anchorsMatchLines], in: "- [ ]").isEmpty)
    }

    // MARK: - Blockquote — > text

    @Test("Blockquote pattern matches > text")
    func blockquoteMatches() {
        let pattern = #"^(>+)\s(.+)$"#
        let input = "> Important note"
        let result = matches(pattern: pattern, options: [.anchorsMatchLines], in: input)
        #expect(result.count == 1)
        #expect(captureGroup(1, in: result[0], string: input) == ">")
        #expect(captureGroup(2, in: result[0], string: input) == "Important note")
    }

    @Test("Blockquote pattern matches nested >>")
    func blockquoteNested() {
        let pattern = #"^(>+)\s(.+)$"#
        let input = ">> Nested quote"
        let result = matches(pattern: pattern, options: [.anchorsMatchLines], in: input)
        #expect(result.count == 1)
        #expect(captureGroup(1, in: result[0], string: input) == ">>")
    }

    @Test("Blockquote does not match mid-line >")
    func blockquoteNoMidLine() {
        let pattern = #"^(>+)\s(.+)$"#
        #expect(matches(pattern: pattern, options: [.anchorsMatchLines], in: "5 > 3").isEmpty)
    }

    // MARK: - Horizontal rule — --- or ***

    @Test("Horizontal rule matches ---")
    func hrDashes() {
        let pattern = #"^([-*]{3,})$"#
        let input = "---"
        let result = matches(pattern: pattern, options: [.anchorsMatchLines], in: input)
        #expect(result.count == 1)
    }

    @Test("Horizontal rule matches ***")
    func hrAsterisks() {
        let pattern = #"^([-*]{3,})$"#
        let input = "***"
        let result = matches(pattern: pattern, options: [.anchorsMatchLines], in: input)
        #expect(result.count == 1)
    }

    @Test("Horizontal rule matches long -----")
    func hrLong() {
        let pattern = #"^([-*]{3,})$"#
        let input = "-----"
        let result = matches(pattern: pattern, options: [.anchorsMatchLines], in: input)
        #expect(result.count == 1)
    }

    @Test("Horizontal rule does not match --")
    func hrNoShort() {
        let pattern = #"^([-*]{3,})$"#
        #expect(matches(pattern: pattern, options: [.anchorsMatchLines], in: "--").isEmpty)
    }

    @Test("Horizontal rule does not match text with dashes")
    func hrNoText() {
        let pattern = #"^([-*]{3,})$"#
        #expect(matches(pattern: pattern, options: [.anchorsMatchLines], in: "---text").isEmpty)
    }

    // MARK: - Tag — #tagname

    @Test("Tag pattern matches simple tag")
    func tagSimple() {
        let pattern = #"(?:^|(?<=\s))#[a-zA-ZäöüÄÖÜß][a-zA-Z0-9äöüÄÖÜß_-]*"#
        let result = matches(pattern: pattern, options: [.anchorsMatchLines], in: "#must-do")
        #expect(result.count == 1)
    }

    @Test("Tag pattern matches tag at start of line")
    func tagStartOfLine() {
        let pattern = #"(?:^|(?<=\s))#[a-zA-ZäöüÄÖÜß][a-zA-Z0-9äöüÄÖÜß_-]*"#
        let result = matches(pattern: pattern, options: [.anchorsMatchLines], in: "#zoo #museum")
        #expect(result.count == 2)
    }

    @Test("Tag pattern matches German umlauts")
    func tagUmlauts() {
        let pattern = #"(?:^|(?<=\s))#[a-zA-ZäöüÄÖÜß][a-zA-Z0-9äöüÄÖÜß_-]*"#
        let result = matches(pattern: pattern, options: [.anchorsMatchLines], in: "#Bücher #übung")
        #expect(result.count == 2)
    }

    @Test("Tag pattern does not match heading (has space after #)")
    func tagNotHeading() {
        let pattern = #"(?:^|(?<=\s))#[a-zA-ZäöüÄÖÜß][a-zA-Z0-9äöüÄÖÜß_-]*"#
        // "# Heading" — tag pattern should NOT match the "#" because it's followed by space
        let result = matches(pattern: pattern, options: [.anchorsMatchLines], in: "# Heading")
        #expect(result.isEmpty)
    }

    @Test("Tag pattern does not match number-only hash (#1)")
    func tagNotNumber() {
        let pattern = #"(?:^|(?<=\s))#[a-zA-ZäöüÄÖÜß][a-zA-Z0-9äöüÄÖÜß_-]*"#
        let result = matches(pattern: pattern, options: [.anchorsMatchLines], in: "#1 ranked")
        #expect(result.isEmpty)
    }

    @Test("Tag pattern matches tag after whitespace mid-line")
    func tagMidLine() {
        let pattern = #"(?:^|(?<=\s))#[a-zA-ZäöüÄÖÜß][a-zA-Z0-9äöüÄÖÜß_-]*"#
        let result = matches(pattern: pattern, options: [.anchorsMatchLines], in: "text #important here")
        #expect(result.count == 1)
    }

    @Test("Tag pattern matches tag with underscores and hyphens")
    func tagSpecialChars() {
        let pattern = #"(?:^|(?<=\s))#[a-zA-ZäöüÄÖÜß][a-zA-Z0-9äöüÄÖÜß_-]*"#
        let result = matches(pattern: pattern, options: [.anchorsMatchLines], in: "#must_do #high-priority")
        #expect(result.count == 2)
    }

    // MARK: - Regex compilation (all patterns valid)

    @Test("All 16 highlighting patterns compile successfully")
    func allPatternsCompile() {
        let patterns: [(String, NSRegularExpression.Options)] = [
            (#"^(#{1})\s(.+)$"#, [.anchorsMatchLines]),
            (#"^(#{2})\s(.+)$"#, [.anchorsMatchLines]),
            (#"^(#{3})\s(.+)$"#, [.anchorsMatchLines]),
            (#"(\*\*|__)(.+?)(\*\*|__)"#, []),
            (#"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#, []),
            (#"(?<!_)_(?!_)(.+?)(?<!_)_(?!_)"#, []),
            (#"(~~)(.+?)(~~)"#, []),
            (#"(`+)(.+?)(\1)"#, []),
            (#"(`{3,})[\s\S]*?\1"#, []),
            (#"(!?\[)([^\]]+)(\]\([^\)]+\))"#, []),
            (#"^(\s*[-*])\s"#, [.anchorsMatchLines]),
            (#"^(\s*\d+\.)\s"#, [.anchorsMatchLines]),
            (#"^(\s*[-*]\s\[[ xX]\])\s"#, [.anchorsMatchLines]),
            (#"^(>+)\s(.+)$"#, [.anchorsMatchLines]),
            (#"^([-*]{3,})$"#, [.anchorsMatchLines]),
            (#"(?:^|(?<=\s))#[a-zA-ZäöüÄÖÜß][a-zA-Z0-9äöüÄÖÜß_-]*"#, [.anchorsMatchLines]),
        ]

        for (pattern, options) in patterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: options)
            #expect(regex != nil, "Pattern failed to compile: \(pattern)")
        }
    }

    // MARK: - Combined document highlighting

    @Test("All patterns match expected constructs in a full document")
    func fullDocumentPatterns() {
        let document = """
        # Title
        ## Section
        ### Subsection
        #must-do #zoo 🦁

        Some **bold** and *italic* and `code` text.
        Also ~~strikethrough~~ and _underline italic_.

        - List item 1
        * List item 2
        1. Ordered item

        - [ ] Unchecked task
        - [x] Checked task

        > A blockquote

        [Link](https://example.com)

        ---
        """

        // Verify each pattern finds at least one match in the document
        let patternsWithOptions: [(String, NSRegularExpression.Options, String)] = [
            (#"^(#{1})\s(.+)$"#, [.anchorsMatchLines], "H1"),
            (#"^(#{2})\s(.+)$"#, [.anchorsMatchLines], "H2"),
            (#"^(#{3})\s(.+)$"#, [.anchorsMatchLines], "H3"),
            (#"(\*\*|__)(.+?)(\*\*|__)"#, [], "Bold"),
            (#"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#, [], "Italic-*"),
            (#"(?<!_)_(?!_)(.+?)(?<!_)_(?!_)"#, [], "Italic-_"),
            (#"(~~)(.+?)(~~)"#, [], "Strikethrough"),
            (#"(`+)(.+?)(\1)"#, [], "Inline code"),
            (#"(!?\[)([^\]]+)(\]\([^\)]+\))"#, [], "Link"),
            (#"^(\s*[-*])\s"#, [.anchorsMatchLines], "Unordered list"),
            (#"^(\s*\d+\.)\s"#, [.anchorsMatchLines], "Ordered list"),
            (#"^(\s*[-*]\s\[[ xX]\])\s"#, [.anchorsMatchLines], "Task list"),
            (#"^(>+)\s(.+)$"#, [.anchorsMatchLines], "Blockquote"),
            (#"^([-*]{3,})$"#, [.anchorsMatchLines], "Horizontal rule"),
            (#"(?:^|(?<=\s))#[a-zA-ZäöüÄÖÜß][a-zA-Z0-9äöüÄÖÜß_-]*"#, [.anchorsMatchLines], "Tag"),
        ]

        for (pattern, options, name) in patternsWithOptions {
            let result = matches(pattern: pattern, options: options, in: document)
            #expect(!result.isEmpty, "Pattern '\(name)' should match in the full document")
        }
    }
}
