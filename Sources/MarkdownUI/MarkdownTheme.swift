//
//  MarkdownTheme.swift
//  AssistanceKit
//
//  Colour and typography configuration for Markdown syntax highlighting.
//  Per ADR-0005: JSON-serializable, per-instance themes with Light/Dark variants.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - MarkdownTheme

/// Colour and typography configuration for the Markdown editor.
///
/// A `MarkdownTheme` bundles a ``name``, ``light`` and ``dark`` appearance
/// variants, and shared ``typography`` settings. All colours are stored as
/// CSS hex strings (e.g. `"#007AFF"`) so the model is free of UIKit/AppKit
/// dependencies and can be decoded from JSON, persisted, or passed between layers.
///
/// ### Built-in Themes
///
/// ```swift
/// let theme = MarkdownTheme.default
/// ```
///
/// ### JSON Loading
///
/// ```swift
/// let data = try Data(contentsOf: themeURL)
/// let theme = try JSONDecoder().decode(MarkdownTheme.self, from: data)
/// ```
///
/// ### Resolving for Light / Dark Mode
///
/// ```swift
/// let colors = theme.appearance(for: .dark)
/// // → theme.dark
/// ```
///
/// - SeeAlso: ``MarkdownEditorView``
/// - SeeAlso: `ADR-0005-theme-system-architecture.md`
public struct MarkdownTheme: Codable, Sendable, Equatable {

    // MARK: - Properties

    /// Display name of the theme (e.g. `"Ocean Blue"`, `"Default"`).
    public var name: String

    /// Light mode appearance colours.
    public var light: Appearance

    /// Dark mode appearance colours.
    public var dark: Appearance

    /// Typography settings (shared between Light and Dark).
    public var typography: Typography

    // MARK: - Init

    /// Creates a Markdown theme with full configuration.
    ///
    /// - Parameters:
    ///   - name: Display name of the theme.
    ///   - light: Light mode appearance.
    ///   - dark: Dark mode appearance.
    ///   - typography: Typography settings.
    public init(
        name: String,
        light: Appearance,
        dark: Appearance,
        typography: Typography = .default
    ) {
        self.name = name
        self.light = light
        self.dark = dark
        self.typography = typography
    }

    // MARK: - Codable (supports both new and legacy JSON formats)

    private enum CodingKeys: String, CodingKey {
        case name
        case light
        case dark
        case typography
    }

    /// Legacy keys from the original 4-colour schema.
    private enum LegacyCodingKeys: String, CodingKey {
        case accent
        case syntax
        case codeForeground = "code_foreground"
        case codeBackground = "code_background"
    }

    public init(from decoder: Decoder) throws {
        // Try the new schema first
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           container.contains(.light) {
            let name = (try? container.decode(String.self, forKey: .name)) ?? "Unnamed"
            let light = try container.decode(Appearance.self, forKey: .light)
            let dark = try container.decode(Appearance.self, forKey: .dark)
            let typography = (try? container.decode(Typography.self, forKey: .typography)) ?? .default
            self.init(name: name, light: light, dark: dark, typography: typography)
            return
        }

        // Fall back to legacy 4-colour schema
        let container = try decoder.container(keyedBy: LegacyCodingKeys.self)
        let accent = try container.decode(String.self, forKey: .accent)
        let syntax = try container.decode(String.self, forKey: .syntax)
        let codeFg = try container.decode(String.self, forKey: .codeForeground)
        let codeBg = try container.decode(String.self, forKey: .codeBackground)
        self.init(accent: accent, syntax: syntax, codeForeground: codeFg, codeBackground: codeBg)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(light, forKey: .light)
        try container.encode(dark, forKey: .dark)
        try container.encode(typography, forKey: .typography)
    }

    // MARK: - Appearance Resolution

    /// The color scheme used to resolve a theme's appearance.
    public enum ColorScheme: Sendable {
        /// Light appearance.
        case light
        /// Dark appearance.
        case dark
    }

    /// Returns the appearance matching the given color scheme.
    ///
    /// - Parameter colorScheme: `.light` or `.dark`.
    /// - Returns: The corresponding ``Appearance``.
    public func appearance(for colorScheme: ColorScheme) -> Appearance {
        switch colorScheme {
        case .light: return light
        case .dark:  return dark
        }
    }

    // MARK: - Built-in Themes

    /// Default theme with balanced light and dark appearances.
    ///
    /// Uses iOS system blue as accent with a green code highlight.
    public static let `default` = MarkdownTheme(
        name: "Default",
        light: .defaultLight,
        dark: .defaultDark
    )

    /// Convenience alias — returns the default theme.
    ///
    /// Provided for backward compatibility with code that referenced
    /// `MarkdownTheme.defaultLight`.
    public static let defaultLight = MarkdownTheme.default

    /// Convenience alias — returns the default theme.
    ///
    /// Provided for backward compatibility with code that referenced
    /// `MarkdownTheme.defaultDark`.
    public static let defaultDark = MarkdownTheme.default

    // MARK: - Legacy Convenience Init

    /// Creates a theme from four flat hex colours (legacy API).
    ///
    /// Both light and dark appearances use the same colours. Prefer the
    /// full initializer for new code.
    ///
    /// - Parameters:
    ///   - accent: Accent hex (e.g. `"#007AFF"`).
    ///   - syntax: Syntax marker hex.
    ///   - codeForeground: Code text hex.
    ///   - codeBackground: Code background tint hex.
    public init(accent: String, syntax: String, codeForeground: String, codeBackground: String) {
        let appearance = Appearance(
            headingColor: accent,
            bodyColor: "#333333",
            accentColor: accent,
            syntaxColor: syntax,
            codeForeground: codeForeground,
            codeBackground: codeBackground,
            blockquoteColor: syntax,
            backgroundColor: "#FFFFFF"
        )
        self.name = "Custom"
        self.light = appearance
        self.dark = appearance
        self.typography = .default
    }

    // MARK: - Legacy Computed Properties

    /// Accent colour from the light appearance (legacy API).
    ///
    /// Prefer `theme.light.accentColor` or `theme.appearance(for:).accentColor`
    /// for new code.
    public var accent: String { light.accentColor }

    /// Syntax marker colour from the light appearance (legacy API).
    public var syntax: String { light.syntaxColor }

    /// Code foreground colour from the light appearance (legacy API).
    public var codeForeground: String { light.codeForeground }

    /// Code background colour from the light appearance (legacy API).
    public var codeBackground: String { light.codeBackground }
}

// MARK: - MarkdownTheme.Appearance

extension MarkdownTheme {

    /// Defines the colour palette for a single appearance mode (light or dark).
    ///
    /// All colours are CSS hex strings (e.g. `"#007AFF"`) for platform independence.
    public struct Appearance: Codable, Sendable, Equatable {

        /// Colour for heading text (H1, H2, H3).
        public var headingColor: String

        /// Colour for body/paragraph text.
        public var bodyColor: String

        /// Accent colour — applied to heading markers, link text, list bullets, and tags.
        public var accentColor: String

        /// Syntax-marker colour — applied to `**`, `*`, `~~`, `` ` `` delimiters
        /// and blockquote markers.
        public var syntaxColor: String

        /// Foreground colour for inline and fenced code text.
        public var codeForeground: String

        /// Background tint for inline and fenced code regions.
        public var codeBackground: String

        /// Colour for blockquote text and indicators.
        public var blockquoteColor: String

        /// Background colour for the editor surface.
        public var backgroundColor: String

        // MARK: Coding Keys

        private enum CodingKeys: String, CodingKey {
            case headingColor    = "heading_color"
            case bodyColor       = "body_color"
            case accentColor     = "accent_color"
            case syntaxColor     = "syntax_color"
            case codeForeground  = "code_foreground"
            case codeBackground  = "code_background"
            case blockquoteColor = "blockquote_color"
            case backgroundColor = "background_color"
        }

        /// Creates an appearance with explicit hex colour strings.
        public init(
            headingColor: String,
            bodyColor: String,
            accentColor: String,
            syntaxColor: String,
            codeForeground: String,
            codeBackground: String,
            blockquoteColor: String,
            backgroundColor: String
        ) {
            self.headingColor = headingColor
            self.bodyColor = bodyColor
            self.accentColor = accentColor
            self.syntaxColor = syntaxColor
            self.codeForeground = codeForeground
            self.codeBackground = codeBackground
            self.blockquoteColor = blockquoteColor
            self.backgroundColor = backgroundColor
        }

        // MARK: Built-in Appearances

        /// Default light appearance.
        public static let defaultLight = Appearance(
            headingColor:    "#1A1A1A",
            bodyColor:       "#333333",
            accentColor:     "#007AFF",
            syntaxColor:     "#8E8E93",
            codeForeground:  "#34C759",
            codeBackground:  "#F0FFF4",
            blockquoteColor: "#6C757D",
            backgroundColor: "#FFFFFF"
        )

        /// Default dark appearance.
        public static let defaultDark = Appearance(
            headingColor:    "#F5F5F7",
            bodyColor:       "#D1D1D6",
            accentColor:     "#0A84FF",
            syntaxColor:     "#636366",
            codeForeground:  "#30D158",
            codeBackground:  "#0D2010",
            blockquoteColor: "#8E8E93",
            backgroundColor: "#000000"
        )
    }
}

// MARK: - MarkdownTheme.Typography

extension MarkdownTheme {

    /// Typography settings shared between light and dark appearances.
    public struct Typography: Codable, Sendable, Equatable {

        /// Base body font size in points. Default: `17` (iOS body).
        ///
        /// When ``usesDynamicType`` is `true`, this value is used as the base
        /// size that iOS Dynamic Type scales up or down. When `false`, fonts
        /// use this size exactly.
        public var bodyFontSize: CGFloat

        /// Scale factor for H1 headings relative to body font size.
        /// H2 uses `headingScale * 0.85`, H3 uses `headingScale * 0.7`.
        public var headingScale: CGFloat

        /// Extra line spacing in points. Default: `4`.
        public var lineSpacing: CGFloat

        /// Extra spacing between paragraphs in points. Default: `8`.
        public var paragraphSpacing: CGFloat

        /// Whether the editor respects the iOS Dynamic Type setting.
        ///
        /// When `true` (default), font sizes scale with the user's preferred
        /// content size category (`UIContentSizeCategory`). The ``bodyFontSize``
        /// acts as the base size that `UIFontMetrics` scales from.
        ///
        /// When `false`, fonts use the exact sizes specified by ``bodyFontSize``
        /// and ``headingScale`` without any system scaling.
        public var usesDynamicType: Bool

        // MARK: Coding Keys

        private enum CodingKeys: String, CodingKey {
            case bodyFontSize      = "body_font_size"
            case headingScale      = "heading_scale"
            case lineSpacing       = "line_spacing"
            case paragraphSpacing  = "paragraph_spacing"
            case usesDynamicType   = "uses_dynamic_type"
        }

        /// Creates typography settings.
        ///
        /// - Parameters:
        ///   - bodyFontSize: Base body font size in points. Default: `17`.
        ///   - headingScale: Scale factor for H1 relative to body. Default: `1.5`.
        ///   - lineSpacing: Extra line spacing in points. Default: `4`.
        ///   - paragraphSpacing: Extra paragraph spacing in points. Default: `8`.
        ///   - usesDynamicType: Whether to respect iOS Dynamic Type. Default: `true`.
        public init(
            bodyFontSize: CGFloat = 17,
            headingScale: CGFloat = 1.5,
            lineSpacing: CGFloat = 4,
            paragraphSpacing: CGFloat = 8,
            usesDynamicType: Bool = true
        ) {
            self.bodyFontSize = bodyFontSize
            self.headingScale = headingScale
            self.lineSpacing = lineSpacing
            self.paragraphSpacing = paragraphSpacing
            self.usesDynamicType = usesDynamicType
        }

        // MARK: Codable (backward-compatible decoding)

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            bodyFontSize = try container.decode(CGFloat.self, forKey: .bodyFontSize)
            headingScale = try container.decode(CGFloat.self, forKey: .headingScale)
            lineSpacing = try container.decode(CGFloat.self, forKey: .lineSpacing)
            paragraphSpacing = try container.decode(CGFloat.self, forKey: .paragraphSpacing)
            usesDynamicType = (try? container.decode(Bool.self, forKey: .usesDynamicType)) ?? true
        }

        /// Default typography matching iOS system body text with Dynamic Type enabled.
        public static let `default` = Typography()
    }
}
