import Testing
@testable import MarkdownUI

// MARK: - MarkdownBlockParser Tests

@Suite("MarkdownBlockParser Tests")
struct MarkdownBlockParserTests {

    // MARK: - Headings

    @Test("H1 heading")
    func h1Heading() {
        let blocks = MarkdownBlockParser.parse("# Title")
        #expect(blocks == [.h1("Title")])
    }

    @Test("H2 heading")
    func h2Heading() {
        let blocks = MarkdownBlockParser.parse("## Section")
        #expect(blocks == [.h2("Section")])
    }

    @Test("H3 heading")
    func h3Heading() {
        let blocks = MarkdownBlockParser.parse("### Subsection")
        #expect(blocks == [.h3("Subsection")])
    }

    @Test("H3 is not confused with H2")
    func h3NotH2() {
        let blocks = MarkdownBlockParser.parse("### Three hashes")
        #expect(blocks == [.h3("Three hashes")])
    }

    @Test("H2 is not confused with H1")
    func h2NotH1() {
        let blocks = MarkdownBlockParser.parse("## Two hashes")
        #expect(blocks == [.h2("Two hashes")])
    }

    @Test("All heading levels in sequence")
    func allHeadings() {
        let md = """
        # H1
        ## H2
        ### H3
        """
        let blocks = MarkdownBlockParser.parse(md)
        #expect(blocks == [.h1("H1"), .h2("H2"), .h3("H3")])
    }

    @Test("Heading with emoji")
    func headingEmoji() {
        let blocks = MarkdownBlockParser.parse("## 📍 Ort / Location")
        #expect(blocks == [.h2("📍 Ort / Location")])
    }

    // MARK: - Paragraphs

    @Test("Single paragraph")
    func singleParagraph() {
        let blocks = MarkdownBlockParser.parse("Hello world")
        #expect(blocks == [.paragraph("Hello world")])
    }

    @Test("Consecutive lines merge into one paragraph")
    func multiLineParagraph() {
        let md = """
        Line one
        Line two
        Line three
        """
        let blocks = MarkdownBlockParser.parse(md)
        #expect(blocks == [.paragraph("Line one\nLine two\nLine three")])
    }

    @Test("Paragraphs separated by blank line")
    func twoParas() {
        let md = """
        First para

        Second para
        """
        let blocks = MarkdownBlockParser.parse(md)
        #expect(blocks == [
            .paragraph("First para"),
            .blank,
            .paragraph("Second para"),
        ])
    }

    // MARK: - Lists

    @Test("Unordered list items — dash")
    func unorderedDash() {
        let md = """
        - Item A
        - Item B
        """
        let blocks = MarkdownBlockParser.parse(md)
        #expect(blocks == [
            .listItem("Item A", 0),
            .listItem("Item B", 0),
        ])
    }

    @Test("Unordered list items — asterisk")
    func unorderedAsterisk() {
        let md = """
        * Alpha
        * Beta
        """
        let blocks = MarkdownBlockParser.parse(md)
        #expect(blocks == [
            .listItem("Alpha", 0),
            .listItem("Beta", 0),
        ])
    }

    @Test("Nested unordered list — 2 spaces = level 1")
    func nestedList() {
        let md = """
        - Top
          - Nested
            - Deep
        """
        let blocks = MarkdownBlockParser.parse(md)
        #expect(blocks == [
            .listItem("Top", 0),
            .listItem("Nested", 1),
            .listItem("Deep", 2),
        ])
    }

    @Test("Ordered list items")
    func orderedList() {
        let md = """
        1. First
        2. Second
        3. Third
        """
        let blocks = MarkdownBlockParser.parse(md)
        #expect(blocks == [
            .orderedListItem("First", 1),
            .orderedListItem("Second", 2),
            .orderedListItem("Third", 3),
        ])
    }

    @Test("Ordered list renumbers sequentially")
    func orderedListRenumber() {
        let md = """
        5. Apple
        10. Banana
        """
        let blocks = MarkdownBlockParser.parse(md)
        #expect(blocks == [
            .orderedListItem("Apple", 1),
            .orderedListItem("Banana", 2),
        ])
    }

    @Test("Ordered counter resets after non-list line")
    func orderedCounterResets() {
        let md = """
        1. First batch
        2. Second batch

        1. New batch
        """
        let blocks = MarkdownBlockParser.parse(md)
        #expect(blocks == [
            .orderedListItem("First batch", 1),
            .orderedListItem("Second batch", 2),
            .blank,
            .orderedListItem("New batch", 1),
        ])
    }

    // MARK: - Blockquotes

    @Test("Blockquote with space after >")
    func blockquoteWithSpace() {
        let blocks = MarkdownBlockParser.parse("> Important note")
        #expect(blocks == [.blockquote("Important note")])
    }

    @Test("Blockquote without space after >")
    func blockquoteNoSpace() {
        let blocks = MarkdownBlockParser.parse(">Tight quote")
        #expect(blocks == [.blockquote("Tight quote")])
    }

    // MARK: - Images

    @Test("Image with alt text")
    func imageWithAlt() {
        let blocks = MarkdownBlockParser.parse("![Photo](https://example.com/img.jpg)")
        #expect(blocks == [.image(alt: "Photo", url: "https://example.com/img.jpg")])
    }

    @Test("Image without alt text")
    func imageNoAlt() {
        let blocks = MarkdownBlockParser.parse("![](local://activity-img-abc.jpg)")
        #expect(blocks == [.image(alt: "", url: "local://activity-img-abc.jpg")])
    }

    @Test("Image inline within text is not extracted")
    func imageInline() {
        let blocks = MarkdownBlockParser.parse("See ![pic](url) here")
        #expect(blocks == [.paragraph("See ![pic](url) here")])
    }

    // MARK: - Horizontal Rules

    @Test("Horizontal rule with dashes")
    func ruleDashes() {
        let blocks = MarkdownBlockParser.parse("---")
        #expect(blocks == [.rule])
    }

    @Test("Horizontal rule with asterisks")
    func ruleAsterisks() {
        let blocks = MarkdownBlockParser.parse("***")
        #expect(blocks == [.rule])
    }

    @Test("Horizontal rule with underscores")
    func ruleUnderscores() {
        let blocks = MarkdownBlockParser.parse("___")
        #expect(blocks == [.rule])
    }

    // MARK: - Blank Lines

    @Test("Leading blank lines are stripped")
    func leadingBlanks() {
        let md = "\n\nHello"
        let blocks = MarkdownBlockParser.parse(md)
        #expect(blocks == [.paragraph("Hello")])
    }

    @Test("Trailing blank lines are stripped")
    func trailingBlanks() {
        let md = "Hello\n\n\n"
        let blocks = MarkdownBlockParser.parse(md)
        #expect(blocks == [.paragraph("Hello")])
    }

    @Test("Consecutive blank lines collapse into one")
    func duplicateBlanks() {
        let md = """
        A


        B
        """
        let blocks = MarkdownBlockParser.parse(md)
        #expect(blocks == [
            .paragraph("A"),
            .blank,
            .paragraph("B"),
        ])
    }

    // MARK: - Tag Lines

    @Test("Tag line is parsed as tagLine block")
    func tagLineParsed() {
        let md = """
        # Title
        #must-do #zoo 🦁
        """
        let blocks = MarkdownBlockParser.parse(md)
        #expect(blocks == [.h1("Title"), .tagLine(["must-do", "zoo"])])
    }

    @Test("Tag line extracts multiple tags")
    func tagLineExtractsMultiple() {
        let tags = MarkdownBlockParser.extractTags(from: "#must-do #zoo #Bücher")
        #expect(tags == ["must-do", "zoo", "Bücher"])
    }

    @Test("Tag extraction from single tag")
    func tagLineSingleTag() {
        let tags = MarkdownBlockParser.extractTags(from: "#tag")
        #expect(tags == ["tag"])
    }

    @Test("Tag extraction ignores non-tag text")
    func tagLineIgnoresNonTag() {
        let tags = MarkdownBlockParser.extractTags(from: "#must-do 🦁 some text")
        #expect(tags == ["must-do"])
    }

    @Test("Tag line detection: valid tags")
    func isTagLineValid() {
        #expect(MarkdownBlockParser.isTagLine("#must-do #zoo"))
        #expect(MarkdownBlockParser.isTagLine("#tag"))
        #expect(MarkdownBlockParser.isTagLine("#Bücher"))
    }

    @Test("Tag line detection: headings are not tags")
    func isTagLineHeadings() {
        #expect(!MarkdownBlockParser.isTagLine("# Heading"))
        #expect(!MarkdownBlockParser.isTagLine("## Section"))
        #expect(!MarkdownBlockParser.isTagLine("### Sub"))
    }

    @Test("Tag line detection: plain text is not a tag")
    func isTagLinePlainText() {
        #expect(!MarkdownBlockParser.isTagLine("Hello world"))
        #expect(!MarkdownBlockParser.isTagLine(""))
    }

    @Test("Tag line with leading number is not a tag")
    func isTagLineNumber() {
        #expect(!MarkdownBlockParser.isTagLine("#123"))
    }

    // MARK: - Task List Items

    @Test("Unchecked task list item with dash")
    func taskListUncheckedDash() {
        let blocks = MarkdownBlockParser.parse("- [ ] Buy groceries")
        #expect(blocks == [.taskListItem("Buy groceries", false)])
    }

    @Test("Checked task list item with dash (lowercase x)")
    func taskListCheckedDash() {
        let blocks = MarkdownBlockParser.parse("- [x] Book tickets")
        #expect(blocks == [.taskListItem("Book tickets", true)])
    }

    @Test("Checked task list item with dash (uppercase X)")
    func taskListCheckedUpperX() {
        let blocks = MarkdownBlockParser.parse("- [X] Done task")
        #expect(blocks == [.taskListItem("Done task", true)])
    }

    @Test("Unchecked task list item with asterisk")
    func taskListUncheckedAsterisk() {
        let blocks = MarkdownBlockParser.parse("* [ ] Pending item")
        #expect(blocks == [.taskListItem("Pending item", false)])
    }

    @Test("Checked task list item with asterisk")
    func taskListCheckedAsterisk() {
        let blocks = MarkdownBlockParser.parse("* [x] Completed item")
        #expect(blocks == [.taskListItem("Completed item", true)])
    }

    @Test("Task list item with plus marker")
    func taskListPlus() {
        let blocks = MarkdownBlockParser.parse("+ [ ] Plus item")
        #expect(blocks == [.taskListItem("Plus item", false)])
    }

    @Test("Multiple task list items — mixed checked/unchecked")
    func taskListMultiple() {
        let md = """
        - [x] Tickets gebucht
        - [ ] Audioguide reservieren
        - [ ] Snacks einpacken
        """
        let blocks = MarkdownBlockParser.parse(md)
        #expect(blocks == [
            .taskListItem("Tickets gebucht", true),
            .taskListItem("Audioguide reservieren", false),
            .taskListItem("Snacks einpacken", false),
        ])
    }

    @Test("Task list items don't consume regular list items")
    func taskListDoesNotConsumeRegularList() {
        let md = """
        - [x] Task done
        - Regular list item
        """
        let blocks = MarkdownBlockParser.parse(md)
        #expect(blocks == [
            .taskListItem("Task done", true),
            .listItem("Regular list item", 0),
        ])
    }

    @Test("Task list items with inline formatting")
    func taskListInlineFormatting() {
        let blocks = MarkdownBlockParser.parse("- [ ] Buy **important** items")
        #expect(blocks == [.taskListItem("Buy **important** items", false)])
    }

    // MARK: - Full Document

    @Test("Full document parses correctly")
    func fullDocument() {
        let md = """
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

        ## 📝 Notizen
        > Unbedingt das Aquarium besuchen!

        1. Eingang am Hardenbergplatz
        2. Ticket online kaufen

        ---

        ![](https://example.com/zoo.jpg)
        """
        let blocks = MarkdownBlockParser.parse(md)
        #expect(blocks == [
            .h1("Berliner Zoo"),
            .tagLine(["must-do", "zoo"]),
            .blank,
            .h2("📍 Ort"),
            .paragraph("Hardenbergplatz 8, 10787 Berlin"),
            .blank,
            .h2("⏱️ Dauer"),
            .paragraph("Ca. **2–3 Stunden**"),
            .blank,
            .h2("💶 Eintritt"),
            .listItem("Erwachsene: 18 €", 0),
            .listItem("Kinder (4–15): 9 €", 0),
            .blank,
            .h2("✅ Checkliste"),
            .taskListItem("Tickets gebucht", true),
            .taskListItem("Audioguide reservieren", false),
            .blank,
            .h2("📝 Notizen"),
            .blockquote("Unbedingt das Aquarium besuchen!"),
            .blank,
            .orderedListItem("Eingang am Hardenbergplatz", 1),
            .orderedListItem("Ticket online kaufen", 2),
            .blank,
            .rule,
            .blank,
            .image(alt: "", url: "https://example.com/zoo.jpg"),
        ])
    }

    @Test("Empty string produces empty blocks")
    func emptyString() {
        let blocks = MarkdownBlockParser.parse("")
        #expect(blocks.isEmpty)
    }

    @Test("Whitespace-only string produces empty blocks")
    func whitespaceOnly() {
        let blocks = MarkdownBlockParser.parse("   \n  \n  ")
        #expect(blocks.isEmpty)
    }

    // MARK: - Active Block Detection

    @Test("blockIndex at start of heading returns 0")
    func blockIndexHeadingStart() {
        let md = "# Title\nSome text"
        #expect(MarkdownBlockParser.blockIndex(at: 0, in: md) == 0)
    }

    @Test("blockIndex in paragraph text after heading")
    func blockIndexParagraph() {
        let md = "# Title\nSome text"
        // "# Title\n" is 8 chars (UTF-16), "Some text" starts at offset 8
        #expect(MarkdownBlockParser.blockIndex(at: 10, in: md) == 1)
    }

    @Test("blockIndex on blank line")
    func blockIndexBlankLine() {
        let md = "# Title\n\nParagraph"
        // Blank line at offset 8 → block index 1 (the .blank)
        let index = MarkdownBlockParser.blockIndex(at: 8, in: md)
        #expect(index == 1)
    }

    @Test("blockIndex in second paragraph after blank")
    func blockIndexSecondParagraph() {
        let md = "First\n\nSecond"
        // blocks: [.paragraph("First"), .blank, .paragraph("Second")]
        // "Second" starts at offset 7
        #expect(MarkdownBlockParser.blockIndex(at: 9, in: md) == 2)
    }

    @Test("blockIndex on list item")
    func blockIndexListItem() {
        let md = "# Title\n- Item A\n- Item B"
        // "- Item A" starts at offset 8, block index 1
        // "- Item B" starts at offset 17, block index 2
        #expect(MarkdownBlockParser.blockIndex(at: 8, in: md) == 1)
        #expect(MarkdownBlockParser.blockIndex(at: 19, in: md) == 2)
    }

    @Test("blockIndex on task list item")
    func blockIndexTaskListItem() {
        let md = "- [x] Done\n- [ ] Pending"
        // Task 1 at offset 0 → block 0
        // Task 2 at offset 11 → block 1
        #expect(MarkdownBlockParser.blockIndex(at: 3, in: md) == 0)
        #expect(MarkdownBlockParser.blockIndex(at: 13, in: md) == 1)
    }

    @Test("blockIndex returns nil for empty string")
    func blockIndexEmptyString() {
        #expect(MarkdownBlockParser.blockIndex(at: 0, in: "") == nil)
    }

    @Test("blockIndex returns nil for negative offset")
    func blockIndexNegativeOffset() {
        #expect(MarkdownBlockParser.blockIndex(at: -1, in: "# Title") == nil)
    }

    @Test("blockIndex at end of document")
    func blockIndexEndOfDoc() {
        let md = "# Title"
        // Offset 7 = end of "# Title" (length 7 in UTF-16)
        let idx = MarkdownBlockParser.blockIndex(at: 7, in: md)
        #expect(idx == 0)
    }

    @Test("blockIndex in multi-block document")
    func blockIndexMultiBlock() {
        let md = "# Title\n\n## Section\nBody text\n\n- Item"
        // blocks: [h1("Title"), blank, h2("Section"), paragraph("Body text"), blank, listItem("Item",0)]
        // h1 at offset 0-6
        // blank at offset 8
        // h2 at offset 9-18
        // paragraph at offset 19-27
        // blank at offset 29
        // listItem at offset 30-35
        #expect(MarkdownBlockParser.blockIndex(at: 3, in: md) == 0) // in h1
        #expect(MarkdownBlockParser.blockIndex(at: 12, in: md) == 2) // in h2
        #expect(MarkdownBlockParser.blockIndex(at: 22, in: md) == 3) // in paragraph
        #expect(MarkdownBlockParser.blockIndex(at: 32, in: md) == 5) // in list item
    }
}
