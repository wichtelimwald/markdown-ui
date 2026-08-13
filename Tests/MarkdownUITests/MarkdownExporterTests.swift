//
//  MarkdownExporterTests.swift
//  AssistanceKitTests
//
//  Tests for MarkdownExporter HTML and NSAttributedString output.
//

import Testing
@testable import MarkdownUI

// MARK: - HTML Export Tests

@Suite("Markdown HTML Export Tests")
struct MarkdownHTMLExportTests {

    // MARK: Block → HTML

    @Test("H1 heading exports to <h1>")
    func h1Export() {
        let blocks: [MarkdownBlock] = [.h1("Hello World")]
        let html = MarkdownExporter.htmlFragment(from: blocks)
        #expect(html.contains("<h1>Hello World</h1>"))
    }

    @Test("H2 heading exports to <h2>")
    func h2Export() {
        let blocks: [MarkdownBlock] = [.h2("Section")]
        let html = MarkdownExporter.htmlFragment(from: blocks)
        #expect(html.contains("<h2>Section</h2>"))
    }

    @Test("H3 heading exports to <h3>")
    func h3Export() {
        let blocks: [MarkdownBlock] = [.h3("Subsection")]
        let html = MarkdownExporter.htmlFragment(from: blocks)
        #expect(html.contains("<h3>Subsection</h3>"))
    }

    @Test("Paragraph exports to <p>")
    func paragraphExport() {
        let blocks: [MarkdownBlock] = [.paragraph("Plain text")]
        let html = MarkdownExporter.htmlFragment(from: blocks)
        #expect(html.contains("<p>Plain text</p>"))
    }

    @Test("List item exports to <ul><li>")
    func listItemExport() {
        let blocks: [MarkdownBlock] = [.listItem("Item", 0)]
        let html = MarkdownExporter.htmlFragment(from: blocks)
        #expect(html.contains("<ul><li>Item</li></ul>"))
    }

    @Test("Ordered list item exports with start attribute")
    func orderedListExport() {
        let blocks: [MarkdownBlock] = [.orderedListItem("First", 1)]
        let html = MarkdownExporter.htmlFragment(from: blocks)
        #expect(html.contains("<ol start=\"1\"><li>First</li></ol>"))
    }

    @Test("Task list checked exports with checkbox")
    func taskCheckedExport() {
        let blocks: [MarkdownBlock] = [.taskListItem("Buy milk", true)]
        let html = MarkdownExporter.htmlFragment(from: blocks)
        #expect(html.contains("☑"))
        #expect(html.contains("Buy milk"))
        #expect(html.contains("line-through"))
    }

    @Test("Task list unchecked exports with empty checkbox")
    func taskUncheckedExport() {
        let blocks: [MarkdownBlock] = [.taskListItem("Buy milk", false)]
        let html = MarkdownExporter.htmlFragment(from: blocks)
        #expect(html.contains("☐"))
        #expect(html.contains("Buy milk"))
        #expect(!html.contains("line-through"))
    }

    @Test("Blockquote exports to <blockquote>")
    func blockquoteExport() {
        let blocks: [MarkdownBlock] = [.blockquote("A wise quote")]
        let html = MarkdownExporter.htmlFragment(from: blocks)
        #expect(html.contains("<blockquote>A wise quote</blockquote>"))
    }

    @Test("Image exports to <img>")
    func imageExport() {
        let blocks: [MarkdownBlock] = [.image(alt: "Photo", url: "https://example.com/img.png")]
        let html = MarkdownExporter.htmlFragment(from: blocks)
        #expect(html.contains("<img"))
        #expect(html.contains("src=\"https://example.com/img.png\""))
        #expect(html.contains("alt=\"Photo\""))
    }

    @Test("Tag line exports with tag spans")
    func tagLineExport() {
        let blocks: [MarkdownBlock] = [.tagLine(["swift", "ios"])]
        let html = MarkdownExporter.htmlFragment(from: blocks)
        #expect(html.contains("#swift"))
        #expect(html.contains("#ios"))
        #expect(html.contains("class=\"tag\""))
    }

    @Test("Rule exports to <hr>")
    func ruleExport() {
        let blocks: [MarkdownBlock] = [.rule]
        let html = MarkdownExporter.htmlFragment(from: blocks)
        #expect(html.contains("<hr>"))
    }

    @Test("Blank block exports empty")
    func blankExport() {
        let blocks: [MarkdownBlock] = [.blank]
        let html = MarkdownExporter.htmlFragment(from: blocks)
        #expect(html.isEmpty)
    }

    // MARK: Inline Markdown → HTML

    @Test("Bold inline converts to <strong>")
    func boldInline() {
        let result = MarkdownExporter.inlineHTML("This is **bold** text")
        #expect(result.contains("<strong>bold</strong>"))
    }

    @Test("Italic inline converts to <em>")
    func italicInline() {
        let result = MarkdownExporter.inlineHTML("This is *italic* text")
        #expect(result.contains("<em>italic</em>"))
    }

    @Test("Code inline converts to <code>")
    func codeInline() {
        let result = MarkdownExporter.inlineHTML("Use `swift test`")
        #expect(result.contains("<code>swift test</code>"))
    }

    @Test("Strikethrough converts to <del>")
    func strikethroughInline() {
        let result = MarkdownExporter.inlineHTML("This is ~~deleted~~ text")
        #expect(result.contains("<del>deleted</del>"))
    }

    @Test("Link converts to <a>")
    func linkInline() {
        let result = MarkdownExporter.inlineHTML("Visit [Apple](https://apple.com)")
        #expect(result.contains("<a href=\"https://apple.com\">Apple</a>"))
    }

    // MARK: HTML Escaping

    @Test("HTML special characters are escaped")
    func htmlEscaping() {
        let result = MarkdownExporter.escapeHTML("<script>alert('xss')</script>")
        #expect(result.contains("&lt;script&gt;"))
        #expect(!result.contains("<script>"))
    }

    @Test("Ampersand is escaped")
    func ampersandEscaping() {
        let result = MarkdownExporter.escapeHTML("Tom & Jerry")
        #expect(result == "Tom &amp; Jerry")
    }

    // MARK: Full Document

    @Test("Full HTML document has doctype and structure")
    func fullDocument() {
        let blocks: [MarkdownBlock] = [.h1("Title"), .paragraph("Body")]
        let html = MarkdownExporter.html(from: blocks, title: "Test")
        #expect(html.hasPrefix("<!DOCTYPE html>"))
        #expect(html.contains("<title>Test</title>"))
        #expect(html.contains("<h1>Title</h1>"))
        #expect(html.contains("<p>Body</p>"))
        #expect(html.contains("</html>"))
    }

    @Test("Multi-block export preserves order")
    func multiBlockOrder() {
        let blocks: [MarkdownBlock] = [
            .h1("Title"),
            .paragraph("Intro"),
            .listItem("Item 1", 0),
            .listItem("Item 2", 0),
            .rule,
            .blockquote("Quote"),
        ]
        let html = MarkdownExporter.htmlFragment(from: blocks)
        let h1Pos = html.range(of: "<h1>")!.lowerBound
        let pPos = html.range(of: "<p>")!.lowerBound
        let hrPos = html.range(of: "<hr>")!.lowerBound
        #expect(h1Pos < pPos)
        #expect(pPos < hrPos)
    }
}
