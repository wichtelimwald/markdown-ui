import Testing
@testable import MarkdownUI

// MARK: - MarkdownSectionParser Tests

@Suite("MarkdownSectionParser Tests")
struct MarkdownSectionParserTests {

    // MARK: - split — empty / no headings

    @Test("Empty string returns empty")
    func splitEmptyString() {
        #expect(MarkdownSectionParser.split("") == [])
    }

    @Test("No headings returns empty")
    func splitNoHeadings() {
        let md = "Just some text\nwith no headings"
        #expect(MarkdownSectionParser.split(md) == [])
    }

    @Test("Only H1 returns empty")
    func splitOnlyH1() {
        let md = "# Top Level Heading\n\nSome body text"
        #expect(MarkdownSectionParser.split(md) == [])
    }

    @Test("Only H3 returns empty")
    func splitOnlyH3() {
        let md = "### Sub Sub Heading\n\nBody"
        #expect(MarkdownSectionParser.split(md) == [])
    }

    // MARK: - split — single section

    @Test("Single section returns one section")
    func splitSingleSection() {
        let md = "## 📍 Ort\nBerlin"
        let result = MarkdownSectionParser.split(md)
        #expect(result.count == 1)
        #expect(result[0].heading == "## 📍 Ort")
        #expect(result[0].body == "Berlin")
    }

    @Test("Single section with empty body")
    func splitSingleSectionEmptyBody() {
        let md = "## 📍 Ort"
        let result = MarkdownSectionParser.split(md)
        #expect(result.count == 1)
        #expect(result[0].heading == "## 📍 Ort")
        #expect(result[0].body.isEmpty)
        #expect(result[0].isEmpty)
    }

    @Test("Single section with multi-line body")
    func splitSingleSectionMultiLine() {
        let md = "## 📝 Notizen\nLine 1\nLine 2\nLine 3"
        let result = MarkdownSectionParser.split(md)
        #expect(result.count == 1)
        #expect(result[0].body == "Line 1\nLine 2\nLine 3")
    }

    // MARK: - split — multiple sections

    @Test("Two sections returns two")
    func splitTwoSections() {
        let md = "## 📍 Ort\nBerlin\n\n## ⏱️ Dauer\n2 Stunden"
        let result = MarkdownSectionParser.split(md)
        #expect(result.count == 2)
        #expect(result[0].heading == "## 📍 Ort")
        #expect(result[1].heading == "## ⏱️ Dauer")
        #expect(result[0].body == "Berlin")
        #expect(result[1].body == "2 Stunden")
    }

    @Test("Full migration output — all sections")
    func splitFullMigration() {
        let md = """
        ## 📍 Ort
        Museumstraße 1, Berlin

        ## ⏱️ Dauer
        2 Stunden

        ## ⏰ Öffnungszeiten
        Mo–Fr 09:00–17:00

        ## 💶 Eintritt
        €22,50

        ## 📞 Kontakt
        +49 30 12345678

        ## 🔗 Links
        [Website](https://example.com)

        ## 📝 Notizen
        Empfohlen für Kinder
        """
        let result = MarkdownSectionParser.split(md)
        #expect(result.count == 7)
    }

    // MARK: - split — H3 inside section body (must NOT split)

    @Test("H3 inside body does not split")
    func splitH3InsideBody() {
        let md = "## 📍 Ort\n### Sub-area\nBerlin"
        let result = MarkdownSectionParser.split(md)
        #expect(result.count == 1)
        #expect(result[0].body.contains("### Sub-area"))
    }

    @Test("H1 inside body does not split")
    func splitH1InsideBody() {
        let md = "## 📍 Ort\n# Main Title\nBerlin"
        let result = MarkdownSectionParser.split(md)
        #expect(result.count == 1)
    }

    // MARK: - split — whitespace trimming

    @Test("Body trims leading and trailing whitespace")
    func splitBodyTrimsWhitespace() {
        let md = "## 📍 Ort\n\n  Berlin  \n\n"
        let result = MarkdownSectionParser.split(md)
        #expect(result[0].body == "Berlin")
    }

    // MARK: - split — content before first ## is ignored

    @Test("Preamble before first heading is ignored")
    func splitPreambleIgnored() {
        let md = "Preamble text\n\n## 📍 Ort\nBerlin"
        let result = MarkdownSectionParser.split(md)
        #expect(result.count == 1)
        #expect(result[0].heading == "## 📍 Ort")
    }

    // MARK: - displayHeading

    @Test("displayHeading strips hash and space")
    func displayHeadingStrips() {
        let section = MarkdownSection(heading: "## 📍 Ort / Location", body: "")
        #expect(section.displayHeading == "📍 Ort / Location")
    }

    @Test("displayHeading plain heading")
    func displayHeadingPlain() {
        let section = MarkdownSection(heading: "## Notes", body: "")
        #expect(section.displayHeading == "Notes")
    }

    // MARK: - isEmpty

    @Test("Empty body is empty")
    func isEmptyEmptyBody() {
        let section = MarkdownSection(heading: "## H", body: "")
        #expect(section.isEmpty)
    }

    @Test("Whitespace body is empty")
    func isEmptyWhitespace() {
        let section = MarkdownSection(heading: "## H", body: "   \n\t  ")
        #expect(section.isEmpty)
    }

    @Test("Non-empty body is not empty")
    func isEmptyNonEmpty() {
        let section = MarkdownSection(heading: "## H", body: "Content")
        #expect(!section.isEmpty)
    }

    // MARK: - join — empty

    @Test("Join empty sections returns empty string")
    func joinEmpty() {
        #expect(MarkdownSectionParser.join([]) == "")
    }

    // MARK: - join — single section

    @Test("Join single section with body")
    func joinSingleWithBody() {
        let section = MarkdownSection(heading: "## 📍 Ort", body: "Berlin")
        #expect(MarkdownSectionParser.join([section]) == "## 📍 Ort\nBerlin")
    }

    @Test("Join single section with empty body")
    func joinSingleEmptyBody() {
        let section = MarkdownSection(heading: "## 📍 Ort", body: "")
        #expect(MarkdownSectionParser.join([section]) == "## 📍 Ort")
    }

    // MARK: - join — multiple sections

    @Test("Join two sections separated by blank line")
    func joinTwoSections() {
        let s1 = MarkdownSection(heading: "## 📍 Ort", body: "Berlin")
        let s2 = MarkdownSection(heading: "## ⏱️ Dauer", body: "2h")
        #expect(MarkdownSectionParser.join([s1, s2]) == "## 📍 Ort\nBerlin\n\n## ⏱️ Dauer\n2h")
    }

    // MARK: - Roundtrip

    @Test("Split-join roundtrip single section")
    func roundtripSingle() {
        let original = "## 📍 Ort\nBerlin"
        let sections = MarkdownSectionParser.split(original)
        let rebuilt  = MarkdownSectionParser.join(sections)
        #expect(original == rebuilt)
    }

    @Test("Split-join roundtrip two sections")
    func roundtripTwo() {
        let original = "## 📍 Ort\nBerlin\n\n## ⏱️ Dauer\n2h"
        let sections = MarkdownSectionParser.split(original)
        let rebuilt  = MarkdownSectionParser.join(sections)
        #expect(original == rebuilt)
    }

    @Test("Split-join roundtrip full migration output")
    func roundtripFull() {
        let original = """
        ## 📍 Ort
        Museumstraße 1, Berlin

        ## ⏱️ Dauer
        2 Stunden

        ## 📝 Notizen
        Empfohlen für Kinder
        """
        let sections = MarkdownSectionParser.split(original)
        let rebuilt  = MarkdownSectionParser.join(sections)
        #expect(original == rebuilt)
    }

    // MARK: - Editing roundtrip

    @Test("Edit roundtrip — modifying body")
    func editRoundtripModify() {
        let original = "## 📍 Ort\nBerlin\n\n## ⏱️ Dauer\n2h"
        var sections = MarkdownSectionParser.split(original)
        sections[0].body = "Amsterdam"
        let rebuilt = MarkdownSectionParser.join(sections)
        #expect(rebuilt == "## 📍 Ort\nAmsterdam\n\n## ⏱️ Dauer\n2h")
    }

    @Test("Edit roundtrip — deleting section")
    func editRoundtripDelete() {
        let original = "## 📍 Ort\nBerlin\n\n## ⏱️ Dauer\n2h"
        var sections = MarkdownSectionParser.split(original)
        sections.removeAll { $0.heading == "## ⏱️ Dauer" }
        let rebuilt = MarkdownSectionParser.join(sections)
        #expect(rebuilt == "## 📍 Ort\nBerlin")
    }

    @Test("Edit roundtrip — adding section")
    func editRoundtripAdd() {
        let original = "## 📍 Ort\nBerlin"
        var sections = MarkdownSectionParser.split(original)
        sections.append(MarkdownSection(heading: "## ⏱️ Dauer", body: "2h"))
        let rebuilt = MarkdownSectionParser.join(sections)
        #expect(rebuilt == "## 📍 Ort\nBerlin\n\n## ⏱️ Dauer\n2h")
    }
}
