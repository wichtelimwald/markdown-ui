//
//  MarkdownTagCompletionTests.swift
//  AssistanceKitTests
//
//  Tests for tag prefix extraction and autocompletion logic.
//

import Foundation
import Testing
@testable import MarkdownUI

// MARK: - Tag Prefix Extraction Tests

@Suite("Tag Prefix Extraction Tests")
struct TagPrefixExtractionTests {

    @Test("Extracts simple tag prefix at cursor")
    func simpleTagPrefix() {
        let text = "Hello #mus"
        //         0123456789
        let result = extractTagPrefix(at: 10, in: text)
        #expect(result?.prefix == "mus")
        #expect(result?.range == NSRange(location: 6, length: 4))
    }

    @Test("Extracts empty prefix right after #")
    func emptyPrefixAfterHash() {
        let text = "Hello #"
        //         0123456
        let result = extractTagPrefix(at: 7, in: text)
        #expect(result?.prefix == "")
        #expect(result?.range == NSRange(location: 6, length: 1))
    }

    @Test("Extracts tag at start of line")
    func tagAtLineStart() {
        let text = "#tag"
        let result = extractTagPrefix(at: 4, in: text)
        #expect(result?.prefix == "tag")
        #expect(result?.range == NSRange(location: 0, length: 4))
    }

    @Test("Extracts tag after newline")
    func tagAfterNewline() {
        let text = "Line one\n#mu"
        //         01234567 8 9 10 11
        let result = extractTagPrefix(at: 12, in: text)
        #expect(result?.prefix == "mu")
        #expect(result?.range == NSRange(location: 9, length: 3))
    }

    @Test("Returns nil when cursor not in tag")
    func noTagAtCursor() {
        let text = "Hello world"
        let result = extractTagPrefix(at: 5, in: text)
        #expect(result == nil)
    }

    @Test("Returns nil for heading (# followed by space)")
    func headingNotTag() {
        let text = "# Heading"
        let result = extractTagPrefix(at: 2, in: text)
        // After `# ` — cursor is after space, not in a tag.
        #expect(result == nil)
    }

    @Test("Returns nil when # is mid-word")
    func hashMidWord() {
        let text = "C#sharp"
        // `#` is preceded by `C` (not whitespace), so not a valid tag start.
        let result = extractTagPrefix(at: 7, in: text)
        #expect(result == nil)
    }

    @Test("Extracts tag with hyphens and underscores")
    func tagWithHyphensUnderscores() {
        let text = "Tags: #must-do_now"
        //         0123456789...
        let result = extractTagPrefix(at: 18, in: text)
        #expect(result?.prefix == "must-do_now")
    }

    @Test("Extracts tag with German umlauts")
    func tagWithUmlauts() {
        let text = "#München"
        let result = extractTagPrefix(at: (text as NSString).length, in: text)
        #expect(result?.prefix == "München")
    }

    @Test("Returns nil at offset 0")
    func offsetZero() {
        let text = "#tag"
        let result = extractTagPrefix(at: 0, in: text)
        #expect(result == nil)
    }

    @Test("Returns nil for empty text")
    func emptyText() {
        let result = extractTagPrefix(at: 0, in: "")
        #expect(result == nil)
    }

    @Test("Extracts partial prefix mid-tag")
    func partialPrefix() {
        let text = "Hello #important stuff"
        //         01234567890123456789012
        // Cursor at offset 13 → inside `#import` (6 chars after #)
        let result = extractTagPrefix(at: 13, in: text)
        #expect(result?.prefix == "import")
        #expect(result?.range == NSRange(location: 6, length: 7))
    }

    @Test("Returns nil when # starts a number")
    func hashWithNumber() {
        // `#1` — not a valid tag (tag must start with a letter)
        let text = "Issue #1"
        let result = extractTagPrefix(at: 8, in: text)
        #expect(result == nil)
    }
}
