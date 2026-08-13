import Testing
import Foundation
@testable import MarkdownUI

@Suite("MarkdownTheme Tests")
struct MarkdownThemeTests {

    // MARK: - Built-in Themes

    @Test("Default theme has correct light accent")
    func defaultThemeLightAccent() {
        let theme = MarkdownTheme.default
        #expect(theme.light.accentColor == "#007AFF")
    }

    @Test("Default theme has correct dark accent")
    func defaultThemeDarkAccent() {
        let theme = MarkdownTheme.default
        #expect(theme.dark.accentColor == "#0A84FF")
    }

    @Test("Default theme name is 'Default'")
    func defaultThemeName() {
        #expect(MarkdownTheme.default.name == "Default")
    }

    @Test("Default theme has default typography")
    func defaultThemeTypography() {
        let typo = MarkdownTheme.default.typography
        #expect(typo.bodyFontSize == 17)
        #expect(typo.headingScale == 1.5)
        #expect(typo.lineSpacing == 4)
        #expect(typo.paragraphSpacing == 8)
    }

    @Test("defaultLight alias equals default theme")
    func defaultLightAlias() {
        #expect(MarkdownTheme.defaultLight == MarkdownTheme.default)
    }

    @Test("defaultDark alias equals default theme")
    func defaultDarkAlias() {
        #expect(MarkdownTheme.defaultDark == MarkdownTheme.default)
    }

    // MARK: - Appearance Resolution

    @Test("appearance(for: .light) returns light appearance")
    func resolveLight() {
        let theme = MarkdownTheme.default
        let appearance = theme.appearance(for: .light)
        #expect(appearance == theme.light)
    }

    @Test("appearance(for: .dark) returns dark appearance")
    func resolveDark() {
        let theme = MarkdownTheme.default
        let appearance = theme.appearance(for: .dark)
        #expect(appearance == theme.dark)
    }

    // MARK: - Legacy Init

    @Test("Legacy 4-colour init sets both appearances identically")
    func legacyInit() {
        let theme = MarkdownTheme(
            accent: "#FF0000",
            syntax: "#AAAAAA",
            codeForeground: "#00FF00",
            codeBackground: "#F0F0F0"
        )
        #expect(theme.light == theme.dark)
        #expect(theme.light.accentColor == "#FF0000")
        #expect(theme.light.syntaxColor == "#AAAAAA")
        #expect(theme.light.codeForeground == "#00FF00")
        #expect(theme.light.codeBackground == "#F0F0F0")
    }

    @Test("Legacy computed properties delegate to light appearance")
    func legacyComputedProperties() {
        let theme = MarkdownTheme.default
        #expect(theme.accent == theme.light.accentColor)
        #expect(theme.syntax == theme.light.syntaxColor)
        #expect(theme.codeForeground == theme.light.codeForeground)
        #expect(theme.codeBackground == theme.light.codeBackground)
    }

    // MARK: - JSON Encoding / Decoding (New Schema)

    @Test("New schema encodes to JSON with correct keys")
    func encodeNewSchema() throws {
        let theme = MarkdownTheme.default
        let data = try JSONEncoder().encode(theme)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["name"] as? String == "Default")
        #expect(json?["light"] is [String: Any])
        #expect(json?["dark"] is [String: Any])
        #expect(json?["typography"] is [String: Any])
    }

    @Test("New schema roundtrips through JSON")
    func roundtripNewSchema() throws {
        let original = MarkdownTheme(
            name: "Ocean Blue",
            light: .defaultLight,
            dark: .defaultDark,
            typography: Typography(bodyFontSize: 18, headingScale: 1.6, lineSpacing: 5, paragraphSpacing: 10)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MarkdownTheme.self, from: data)
        #expect(decoded == original)
    }

    @Test("Decoding from full JSON with all fields")
    func decodeFullJSON() throws {
        let json = """
        {
          "name": "Test Theme",
          "light": {
            "heading_color": "#111111",
            "body_color": "#222222",
            "accent_color": "#333333",
            "syntax_color": "#444444",
            "code_foreground": "#555555",
            "code_background": "#666666",
            "blockquote_color": "#777777",
            "background_color": "#888888"
          },
          "dark": {
            "heading_color": "#AAAAAA",
            "body_color": "#BBBBBB",
            "accent_color": "#CCCCCC",
            "syntax_color": "#DDDDDD",
            "code_foreground": "#EEEEEE",
            "code_background": "#FFFFFF",
            "blockquote_color": "#999999",
            "background_color": "#000000"
          },
          "typography": {
            "body_font_size": 20,
            "heading_scale": 2.0,
            "line_spacing": 6,
            "paragraph_spacing": 12
          }
        }
        """.data(using: .utf8)!

        let theme = try JSONDecoder().decode(MarkdownTheme.self, from: json)
        #expect(theme.name == "Test Theme")
        #expect(theme.light.headingColor == "#111111")
        #expect(theme.light.accentColor == "#333333")
        #expect(theme.dark.accentColor == "#CCCCCC")
        #expect(theme.dark.backgroundColor == "#000000")
        #expect(theme.typography.bodyFontSize == 20)
        #expect(theme.typography.headingScale == 2.0)
    }

    @Test("Decoding without typography uses defaults")
    func decodeWithoutTypography() throws {
        let json = """
        {
          "name": "Minimal",
          "light": {
            "heading_color": "#111111",
            "body_color": "#222222",
            "accent_color": "#333333",
            "syntax_color": "#444444",
            "code_foreground": "#555555",
            "code_background": "#666666",
            "blockquote_color": "#777777",
            "background_color": "#888888"
          },
          "dark": {
            "heading_color": "#AAAAAA",
            "body_color": "#BBBBBB",
            "accent_color": "#CCCCCC",
            "syntax_color": "#DDDDDD",
            "code_foreground": "#EEEEEE",
            "code_background": "#FFFFFF",
            "blockquote_color": "#999999",
            "background_color": "#000000"
          }
        }
        """.data(using: .utf8)!

        let theme = try JSONDecoder().decode(MarkdownTheme.self, from: json)
        #expect(theme.typography == .default)
    }

    @Test("Decoding without name uses 'Unnamed'")
    func decodeWithoutName() throws {
        let json = """
        {
          "light": {
            "heading_color": "#111111",
            "body_color": "#222222",
            "accent_color": "#333333",
            "syntax_color": "#444444",
            "code_foreground": "#555555",
            "code_background": "#666666",
            "blockquote_color": "#777777",
            "background_color": "#888888"
          },
          "dark": {
            "heading_color": "#AAAAAA",
            "body_color": "#BBBBBB",
            "accent_color": "#CCCCCC",
            "syntax_color": "#DDDDDD",
            "code_foreground": "#EEEEEE",
            "code_background": "#FFFFFF",
            "blockquote_color": "#999999",
            "background_color": "#000000"
          }
        }
        """.data(using: .utf8)!

        let theme = try JSONDecoder().decode(MarkdownTheme.self, from: json)
        #expect(theme.name == "Unnamed")
    }

    // MARK: - Legacy JSON Decoding (Backward Compatibility)

    @Test("Legacy 4-colour JSON decodes successfully")
    func decodeLegacyJSON() throws {
        let json = """
        {
          "accent": "#FF0000",
          "syntax": "#AAAAAA",
          "code_foreground": "#00FF00",
          "code_background": "#F0F0F0"
        }
        """.data(using: .utf8)!

        let theme = try JSONDecoder().decode(MarkdownTheme.self, from: json)
        #expect(theme.accent == "#FF0000")
        #expect(theme.syntax == "#AAAAAA")
        #expect(theme.codeForeground == "#00FF00")
        #expect(theme.codeBackground == "#F0F0F0")
        #expect(theme.name == "Custom")
    }

    @Test("Malformed JSON fails to decode")
    func decodeMalformedJSON() {
        let badData = "not json".data(using: .utf8)!
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(MarkdownTheme.self, from: badData)
        }
    }

    // MARK: - Appearance Defaults

    @Test("defaultLight appearance has correct code colours")
    func defaultLightAppearance() {
        let appearance = MarkdownTheme.Appearance.defaultLight
        #expect(appearance.codeForeground == "#34C759")
        #expect(appearance.codeBackground == "#F0FFF4")
        #expect(appearance.backgroundColor == "#FFFFFF")
    }

    @Test("defaultDark appearance has correct code colours")
    func defaultDarkAppearance() {
        let appearance = MarkdownTheme.Appearance.defaultDark
        #expect(appearance.codeForeground == "#30D158")
        #expect(appearance.codeBackground == "#0D2010")
        #expect(appearance.backgroundColor == "#000000")
    }

    // MARK: - Typography

    @Test("Custom typography values are preserved")
    func customTypography() {
        let typo = MarkdownTheme.Typography(
            bodyFontSize: 22,
            headingScale: 1.8,
            lineSpacing: 6,
            paragraphSpacing: 12
        )
        #expect(typo.bodyFontSize == 22)
        #expect(typo.headingScale == 1.8)
        #expect(typo.lineSpacing == 6)
        #expect(typo.paragraphSpacing == 12)
    }

    @Test("Typography roundtrips through JSON")
    func typographyRoundtrip() throws {
        let original = MarkdownTheme.Typography(
            bodyFontSize: 19,
            headingScale: 1.7,
            lineSpacing: 3,
            paragraphSpacing: 10
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MarkdownTheme.Typography.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - Dynamic Type

    @Test("Default typography has usesDynamicType true")
    func defaultTypographyUsesDynamicType() {
        #expect(MarkdownTheme.Typography.default.usesDynamicType == true)
    }

    @Test("Typography with usesDynamicType false is preserved")
    func typographyDynamicTypeFalse() {
        let typo = MarkdownTheme.Typography(usesDynamicType: false)
        #expect(typo.usesDynamicType == false)
        #expect(typo.bodyFontSize == 17)
    }

    @Test("Typography with usesDynamicType roundtrips through JSON")
    func typographyDynamicTypeRoundtrip() throws {
        let original = MarkdownTheme.Typography(
            bodyFontSize: 20,
            headingScale: 1.6,
            lineSpacing: 5,
            paragraphSpacing: 10,
            usesDynamicType: false
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MarkdownTheme.Typography.self, from: data)
        #expect(decoded == original)
        #expect(decoded.usesDynamicType == false)
    }

    @Test("Typography JSON without uses_dynamic_type defaults to true")
    func typographyMissingDynamicTypeDefaultsTrue() throws {
        let json = """
        {
          "body_font_size": 18,
          "heading_scale": 1.5,
          "line_spacing": 4,
          "paragraph_spacing": 8
        }
        """.data(using: .utf8)!

        let typo = try JSONDecoder().decode(MarkdownTheme.Typography.self, from: json)
        #expect(typo.usesDynamicType == true)
        #expect(typo.bodyFontSize == 18)
    }

    @Test("Typography JSON with uses_dynamic_type false decodes correctly")
    func typographyExplicitDynamicTypeFalse() throws {
        let json = """
        {
          "body_font_size": 22,
          "heading_scale": 1.8,
          "line_spacing": 6,
          "paragraph_spacing": 12,
          "uses_dynamic_type": false
        }
        """.data(using: .utf8)!

        let typo = try JSONDecoder().decode(MarkdownTheme.Typography.self, from: json)
        #expect(typo.usesDynamicType == false)
        #expect(typo.bodyFontSize == 22)
        #expect(typo.headingScale == 1.8)
    }

    @Test("Typographies with different usesDynamicType are not equal")
    func typographyDynamicTypeEquality() {
        let a = MarkdownTheme.Typography(usesDynamicType: true)
        let b = MarkdownTheme.Typography(usesDynamicType: false)
        #expect(a != b)
    }

    @Test("Full theme JSON with uses_dynamic_type decodes correctly")
    func fullThemeWithDynamicType() throws {
        let json = """
        {
          "name": "Custom DT",
          "light": {
            "heading_color": "#111111",
            "body_color": "#222222",
            "accent_color": "#333333",
            "syntax_color": "#444444",
            "code_foreground": "#555555",
            "code_background": "#666666",
            "blockquote_color": "#777777",
            "background_color": "#888888"
          },
          "dark": {
            "heading_color": "#AAAAAA",
            "body_color": "#BBBBBB",
            "accent_color": "#CCCCCC",
            "syntax_color": "#DDDDDD",
            "code_foreground": "#EEEEEE",
            "code_background": "#FFFFFF",
            "blockquote_color": "#999999",
            "background_color": "#000000"
          },
          "typography": {
            "body_font_size": 20,
            "heading_scale": 1.6,
            "line_spacing": 5,
            "paragraph_spacing": 10,
            "uses_dynamic_type": false
          }
        }
        """.data(using: .utf8)!

        let theme = try JSONDecoder().decode(MarkdownTheme.self, from: json)
        #expect(theme.typography.usesDynamicType == false)
        #expect(theme.typography.bodyFontSize == 20)
    }

    // MARK: - Equatable

    @Test("Themes with different names are not equal")
    func differentNamesNotEqual() {
        let a = MarkdownTheme(name: "A", light: .defaultLight, dark: .defaultDark)
        let b = MarkdownTheme(name: "B", light: .defaultLight, dark: .defaultDark)
        #expect(a != b)
    }

    @Test("Themes with different light appearances are not equal")
    func differentLightNotEqual() {
        var altLight = MarkdownTheme.Appearance.defaultLight
        altLight.accentColor = "#FF0000"
        let a = MarkdownTheme(name: "Test", light: .defaultLight, dark: MarkdownTheme.Appearance.defaultDark)
        let b = MarkdownTheme(name: "Test", light: altLight, dark: MarkdownTheme.Appearance.defaultDark)
        #expect(a != b)
    }
}

// Type alias for cleaner test code
private typealias Typography = MarkdownTheme.Typography
