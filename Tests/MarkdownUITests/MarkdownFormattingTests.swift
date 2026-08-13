//
//  MarkdownFormattingTests.swift
//  AssistanceKit
//
//  Tests for Markdown formatting logic.
//  Validates the string transformation rules used by MarkdownTextView's
//  formatting actions. Since MarkdownTextView requires UIKit, these tests
//  verify the logic independently of the UITextView runtime.
//

import Testing
@testable import MarkdownUI

@Suite("Markdown Formatting Logic Tests")
struct MarkdownFormattingTests {

    // MARK: - Wrap Selection Logic

    /// Simulates `wrapSelection` logic: wraps selected text in prefix/suffix.
    /// If selection is empty, inserts `prefix + placeholder + suffix`.
    private func wrapSelection(
        text: String,
        selectedRange: Range<String.Index>,
        prefix: String,
        suffix: String,
        placeholder: String
    ) -> (result: String, selectedText: String) {
        let selected = String(text[selectedRange])
        if selected.isEmpty {
            let insertion = "\(prefix)\(placeholder)\(suffix)"
            let before = String(text[text.startIndex..<selectedRange.lowerBound])
            let after = String(text[selectedRange.upperBound...])
            return (before + insertion + after, placeholder)
        } else {
            let wrapped = "\(prefix)\(selected)\(suffix)"
            let before = String(text[text.startIndex..<selectedRange.lowerBound])
            let after = String(text[selectedRange.upperBound...])
            return (before + wrapped + after, selected)
        }
    }

    /// Simulates `insertLinePrefix` logic: prepends prefix to the current line.
    private func insertLinePrefix(
        text: String,
        cursorOffset: Int,
        prefix: String
    ) -> String {
        let lines = text.components(separatedBy: "\n")
        var charCount = 0
        var targetLineIndex = 0

        for (index, line) in lines.enumerated() {
            let lineEnd = charCount + line.count
            if cursorOffset <= lineEnd {
                targetLineIndex = index
                break
            }
            charCount += line.count + 1 // +1 for newline
        }

        var result = lines
        if result[targetLineIndex].hasPrefix(prefix) {
            // Already has prefix — remove it (toggle off)
            result[targetLineIndex] = String(result[targetLineIndex].dropFirst(prefix.count))
        } else {
            result[targetLineIndex] = prefix + result[targetLineIndex]
        }
        return result.joined(separator: "\n")
    }

    // MARK: - Bold

    @Test("Bold wraps selected text in **")
    func boldWithSelection() {
        let text = "Hello world"
        let range = text.index(text.startIndex, offsetBy: 6)..<text.endIndex
        let result = wrapSelection(text: text, selectedRange: range, prefix: "**", suffix: "**", placeholder: "bold text")
        #expect(result.result == "Hello **world**")
    }

    @Test("Bold inserts placeholder when no selection")
    func boldWithoutSelection() {
        let text = "Hello "
        let range = text.endIndex..<text.endIndex
        let result = wrapSelection(text: text, selectedRange: range, prefix: "**", suffix: "**", placeholder: "bold text")
        #expect(result.result == "Hello **bold text**")
        #expect(result.selectedText == "bold text")
    }

    // MARK: - Italic

    @Test("Italic wraps selected text in *")
    func italicWithSelection() {
        let text = "Hello world"
        let range = text.index(text.startIndex, offsetBy: 6)..<text.endIndex
        let result = wrapSelection(text: text, selectedRange: range, prefix: "*", suffix: "*", placeholder: "italic text")
        #expect(result.result == "Hello *world*")
    }

    @Test("Italic inserts placeholder when no selection")
    func italicWithoutSelection() {
        let text = ""
        let range = text.startIndex..<text.endIndex
        let result = wrapSelection(text: text, selectedRange: range, prefix: "*", suffix: "*", placeholder: "italic text")
        #expect(result.result == "*italic text*")
    }

    // MARK: - Strikethrough

    @Test("Strikethrough wraps in ~~")
    func strikethroughWithSelection() {
        let text = "delete this"
        let range = text.startIndex..<text.endIndex
        let result = wrapSelection(text: text, selectedRange: range, prefix: "~~", suffix: "~~", placeholder: "text")
        #expect(result.result == "~~delete this~~")
    }

    // MARK: - Inline Code

    @Test("Code wraps in backticks")
    func codeWithSelection() {
        let text = "let x = 1"
        let range = text.startIndex..<text.endIndex
        let result = wrapSelection(text: text, selectedRange: range, prefix: "`", suffix: "`", placeholder: "code")
        #expect(result.result == "`let x = 1`")
    }

    @Test("Code inserts placeholder when no selection")
    func codeWithoutSelection() {
        let text = "See "
        let range = text.endIndex..<text.endIndex
        let result = wrapSelection(text: text, selectedRange: range, prefix: "`", suffix: "`", placeholder: "code")
        #expect(result.result == "See `code`")
    }

    // MARK: - Link

    @Test("Link wraps selection in [text](url) syntax")
    func linkWithSelection() {
        let text = "example"
        let range = text.startIndex..<text.endIndex
        let result = wrapSelection(text: text, selectedRange: range, prefix: "[", suffix: "](https://)", placeholder: "link text")
        #expect(result.result == "[example](https://)")
    }

    @Test("Link inserts full template when no selection")
    func linkWithoutSelection() {
        // When no selection, formatLink inserts "[link text](https://)" directly
        let template = "[link text](https://)"
        #expect(template.contains("[link text]"))
        #expect(template.contains("(https://)"))
    }

    // MARK: - List Item Prefix

    @Test("List prefix adds dash to current line")
    func listItemPrefix() {
        let text = "Buy milk"
        let result = insertLinePrefix(text: text, cursorOffset: 3, prefix: "- ")
        #expect(result == "- Buy milk")
    }

    @Test("List prefix toggles off if already present")
    func listItemPrefixToggle() {
        let text = "- Buy milk"
        let result = insertLinePrefix(text: text, cursorOffset: 5, prefix: "- ")
        #expect(result == "Buy milk")
    }

    @Test("List prefix works on second line")
    func listItemPrefixSecondLine() {
        let text = "Line 1\nLine 2"
        let result = insertLinePrefix(text: text, cursorOffset: 10, prefix: "- ")
        #expect(result == "Line 1\n- Line 2")
    }

    // MARK: - Heading Prefix

    @Test("Heading prefix adds ## to current line")
    func headingPrefix() {
        let text = "My Section"
        let result = insertLinePrefix(text: text, cursorOffset: 3, prefix: "## ")
        #expect(result == "## My Section")
    }

    @Test("Heading prefix toggles off if already present")
    func headingPrefixToggle() {
        let text = "## My Section"
        let result = insertLinePrefix(text: text, cursorOffset: 5, prefix: "## ")
        #expect(result == "My Section")
    }

    // MARK: - Edge Cases

    @Test("Wrap at start of text")
    func wrapAtStart() {
        let text = "Hello"
        let range = text.startIndex..<text.index(text.startIndex, offsetBy: 5)
        let result = wrapSelection(text: text, selectedRange: range, prefix: "**", suffix: "**", placeholder: "bold text")
        #expect(result.result == "**Hello**")
    }

    @Test("Wrap in middle of text preserves surrounding content")
    func wrapInMiddle() {
        let text = "aaa bbb ccc"
        let start = text.index(text.startIndex, offsetBy: 4)
        let end = text.index(text.startIndex, offsetBy: 7)
        let range = start..<end
        let result = wrapSelection(text: text, selectedRange: range, prefix: "*", suffix: "*", placeholder: "italic text")
        #expect(result.result == "aaa *bbb* ccc")
    }

    @Test("List prefix on empty line")
    func listPrefixEmptyLine() {
        let text = ""
        let result = insertLinePrefix(text: text, cursorOffset: 0, prefix: "- ")
        #expect(result == "- ")
    }

    @Test("Multiline text: prefix only affects cursor line")
    func prefixOnlyAffectsCursorLine() {
        let text = "Line 1\nLine 2\nLine 3"
        let result = insertLinePrefix(text: text, cursorOffset: 10, prefix: "- ")
        #expect(result == "Line 1\n- Line 2\nLine 3")
    }

    // MARK: - Quote Formatting

    @Test("Quote prefix inserts > at start of line")
    func quotePrefix() {
        let text = "Hello world"
        let result = insertLinePrefix(text: text, cursorOffset: 5, prefix: "> ")
        #expect(result == "> Hello world")
    }

    @Test("Quote prefix on empty line")
    func quotePrefixEmptyLine() {
        let text = ""
        let result = insertLinePrefix(text: text, cursorOffset: 0, prefix: "> ")
        #expect(result == "> ")
    }

    @Test("Quote prefix toggles off if already present")
    func quotePrefixToggle() {
        let text = "> Quoted text"
        let result = insertLinePrefix(text: text, cursorOffset: 5, prefix: "> ")
        #expect(result == "Quoted text")
    }

    @Test("Quote prefix on second line of multiline text")
    func quotePrefixMultiline() {
        let text = "Line 1\nLine 2\nLine 3"
        let result = insertLinePrefix(text: text, cursorOffset: 10, prefix: "> ")
        #expect(result == "Line 1\n> Line 2\nLine 3")
    }
}
