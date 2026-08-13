//
//  MarkdownEditorView.swift
//  AssistanceKit
//
//  Live Markdown editor with syntax highlighting and context-menu formatting.
//  Generalised from toogether for cross-project reuse.
//

#if canImport(UIKit) && canImport(SwiftUI)
import PhotosUI
import SwiftUI
import UIKit

// MARK: - UIView Helpers

private extension UIView {
    /// Walks the responder chain to find the nearest `UIViewController`.
    var closestViewController: UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let vc = next as? UIViewController {
                return vc
            }
            responder = next
        }
        return nil
    }
}

// MARK: - MarkdownTextView

/// `UITextView` subclass that adds Markdown formatting actions to the
/// iOS edit menu (the callout that shows Cut / Copy / Paste / …).
///
/// Formatting works on the **selected text**: if the user selects a word
/// and taps "Bold", the selection is wrapped in `**…**`. When nothing is
/// selected the cursor-position gets a placeholder wrapped in the syntax.
///
/// This mirrors the experience in Apple Notes / Apple Mail where
/// text-formatting options sit right in the context menu — no separate
/// toolbar needed.
public final class MarkdownTextView: UITextView {

    /// Called when the user requests image insertion (via context menu or toolbar).
    /// Set by the ``MarkdownEditorView/Coordinator`` to present the image source picker.
    var onInsertImageRequested: (() -> Void)?

    // MARK: Keyboard Shortcuts (iPad)

    /// Standard formatting keyboard shortcuts for iPad hardware keyboards.
    ///
    /// | Shortcut | Action |
    /// |----------|--------|
    /// | ⌘B | Bold |
    /// | ⌘I | Italic |
    /// | ⌘K | Link |
    /// | ⌘⇧S | Strikethrough |
    /// | ⌘⇧C | Inline code |
    override public var keyCommands: [UIKeyCommand]? {
        [
            UIKeyCommand(title: "Bold", action: #selector(formatBold), input: "b", modifierFlags: .command, discoverabilityTitle: "Bold"),
            UIKeyCommand(title: "Italic", action: #selector(formatItalic), input: "i", modifierFlags: .command, discoverabilityTitle: "Italic"),
            UIKeyCommand(title: "Link", action: #selector(formatLink), input: "k", modifierFlags: .command, discoverabilityTitle: "Link"),
            UIKeyCommand(title: "Strikethrough", action: #selector(formatStrikethrough), input: "s", modifierFlags: [.command, .shift], discoverabilityTitle: "Strikethrough"),
            UIKeyCommand(title: "Code", action: #selector(formatCode), input: "c", modifierFlags: [.command, .shift], discoverabilityTitle: "Code"),
        ]
    }

    // MARK: Context Menu

    override public func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        MainActor.assumeIsolated {
            // Allow our custom formatting actions + all standard actions
            if action == #selector(formatBold)
                || action == #selector(formatItalic)
                || action == #selector(formatCode)
                || action == #selector(formatStrikethrough)
                || action == #selector(formatLink)
                || action == #selector(formatListItem)
                || action == #selector(formatHeading) {
                return true
            }
            return super.canPerformAction(action, withSender: sender)
        }
    }

    /// Builds the iOS context menu, inserting a "Format" submenu with Markdown
    /// formatting actions (Bold, Italic, Code, Strikethrough, Link, List, Heading)
    /// at the start of the standard edit menu.
    override public func buildMenu(with builder: UIMenuBuilder) {
        MainActor.assumeIsolated {
            super.buildMenu(with: builder)

            let formatActions: [UIAction] = [
                UIAction(title: "Bold", image: UIImage(systemName: "bold")) { [weak self] _ in
                    self?.formatBold()
                },
                UIAction(title: "Italic", image: UIImage(systemName: "italic")) { [weak self] _ in
                    self?.formatItalic()
                },
                UIAction(
                    title: "Code",
                    image: UIImage(systemName: "chevron.left.forwardslash.chevron.right")
                ) { [weak self] _ in
                    self?.formatCode()
                },
                UIAction(title: "Strikethrough", image: UIImage(systemName: "strikethrough")) { [weak self] _ in
                    self?.formatStrikethrough()
                },
                UIAction(title: "Link", image: UIImage(systemName: "link")) { [weak self] _ in
                    self?.formatLink()
                },
                UIAction(title: "List", image: UIImage(systemName: "list.bullet")) { [weak self] _ in
                    self?.formatListItem()
                },
                UIAction(title: "Heading", image: UIImage(systemName: "number")) { [weak self] _ in
                    self?.formatHeading()
                },
                UIAction(title: "Insert Image", image: UIImage(systemName: "photo.badge.plus")) { [weak self] _ in
                    self?.onInsertImageRequested?()
                },
            ]

            let formatMenu = UIMenu(
                title: "Format",
                image: UIImage(systemName: "textformat"),
                children: formatActions
            )

            // Insert before the standard "Format" menu if it exists, otherwise at the end
            builder.insertChild(formatMenu, atStartOfMenu: .standardEdit)
        }
    }

    // MARK: - Formatting Actions

    @objc func formatBold() {
        wrapSelection(prefix: "**", suffix: "**", placeholder: "bold text")
        announceFormatting("Bold")
    }

    @objc func formatItalic() {
        wrapSelection(prefix: "*", suffix: "*", placeholder: "italic text")
        announceFormatting("Italic")
    }

    @objc func formatCode() {
        wrapSelection(prefix: "`", suffix: "`", placeholder: "code")
        announceFormatting("Code")
    }

    @objc func formatStrikethrough() {
        wrapSelection(prefix: "~~", suffix: "~~", placeholder: "text")
        announceFormatting("Strikethrough")
    }

    @objc func formatLink() {
        let selected = selectedTextString
        if selected.isEmpty {
            insertTextAtCursor("[link text](https://)")
        } else {
            wrapSelection(prefix: "[", suffix: "](https://)", placeholder: "link text")
        }
        announceFormatting("Link")
    }

    @objc func formatListItem() {
        insertLinePrefix("- ")
        announceFormatting("List item")
    }

    @objc func formatHeading() {
        insertLinePrefix("## ")
        announceFormatting("Heading")
    }

    @objc func formatQuote() {
        insertLinePrefix("> ")
        announceFormatting("Quote")
    }

    /// Posts a VoiceOver announcement when a formatting action is applied.
    ///
    /// - Parameter formatName: Human-readable name of the format (e.g. "Bold").
    private func announceFormatting(_ formatName: String) {
        UIAccessibility.post(notification: .announcement, argument: "\(formatName) applied")
    }

    // MARK: - Text Manipulation Helpers

    /// The currently selected text, or empty string.
    private var selectedTextString: String {
        guard let range = selectedTextRange,
              let selected = text(in: range) else { return "" }
        return selected
    }

    /// Wraps the current selection in prefix/suffix syntax.
    /// If nothing is selected, inserts `prefix + placeholder + suffix` at cursor.
    private func wrapSelection(prefix: String, suffix: String, placeholder: String) {
        guard let range = selectedTextRange else { return }
        let selected = text(in: range) ?? ""

        if selected.isEmpty {
            // Insert placeholder wrapped in syntax at cursor
            let insertion = "\(prefix)\(placeholder)\(suffix)"
            replace(range, withText: insertion)
            // Select the placeholder so the user can immediately type over it
            if let start = position(from: range.start, offset: prefix.count),
               let end = position(from: start, offset: placeholder.count) {
                selectedTextRange = textRange(from: start, to: end)
            }
        } else {
            // Wrap existing selection
            let wrapped = "\(prefix)\(selected)\(suffix)"
            replace(range, withText: wrapped)
        }
    }

    /// Inserts text at the current cursor position.
    private func insertTextAtCursor(_ text: String) {
        guard let range = selectedTextRange else { return }
        replace(range, withText: text)
    }

    /// Inserts a prefix at the beginning of the current line.
    /// If the cursor is at the start of a line already, just prepends.
    private func insertLinePrefix(_ prefix: String) {
        guard let range = selectedTextRange else { return }
        let cursorPosition = offset(from: beginningOfDocument, to: range.start)
        let fullText = self.text ?? ""

        // Find the start of the current line
        let textBefore = String(fullText.prefix(cursorPosition))
        let lineStart = (textBefore.lastIndex(of: "\n").map { fullText.index(after: $0) }) ?? fullText.startIndex
        let lineStartOffset = fullText.distance(from: fullText.startIndex, to: lineStart)

        // Insert the prefix at the line start
        if let insertPos = position(from: beginningOfDocument, offset: lineStartOffset) {
            let insertRange = textRange(from: insertPos, to: insertPos)
            if let insertRange {
                replace(insertRange, withText: prefix)
            }
        }
    }
}

// MARK: - MarkdownImageInsertionDelegate

/// Delegate protocol for handling image storage during image insertion.
///
/// When the user picks an image from the photo library, the editor calls
/// ``storeImage(_:suggestedName:)`` to ask the host app to persist the image
/// and return a URL string for the Markdown `![alt](url)` syntax.
///
/// This follows ADR-0007: the editor stores only Markdown text with image URLs —
/// never binary image data. The host app owns image storage and lifecycle.
///
/// ```swift
/// struct MyImageStore: MarkdownImageInsertionDelegate {
///     func storeImage(_ data: Data, suggestedName: String) async -> String? {
///         let id = UUID().uuidString
///         try? data.write(to: storageURL.appendingPathComponent(id))
///         return "local://\(id)"
///     }
/// }
/// ```
///
/// - SeeAlso: ``MarkdownImageDataProvider`` for the read-side counterpart.
/// - SeeAlso: ADR-0007 for the image handling architecture.
public protocol MarkdownImageInsertionDelegate: Sendable {

    /// Stores image data and returns the URL string to embed in Markdown.
    ///
    /// Called when the user selects a photo from the photo library. The delegate
    /// should persist the image (file system, CloudKit, etc.) and return the URL
    /// that will be used in the `![alt](url)` syntax.
    ///
    /// - Parameters:
    ///   - data: The raw image data (JPEG, PNG, HEIC, etc.).
    ///   - suggestedName: A suggested filename (e.g. `"photo-2026-04-14.jpg"`).
    /// - Returns: The URL string to embed, or `nil` if storage failed.
    func storeImage(_ data: Data, suggestedName: String) async -> String?
}

// MARK: - MarkdownFloatingToolbar

/// A Notion-style floating toolbar that appears above a text selection,
/// offering quick access to Markdown formatting actions.
///
/// Per ADR-0002, the floating toolbar provides: Undo, Redo, Bold, Italic,
/// Strikethrough, Code, and Link. It positions itself above the selection
/// rect (or below if there isn't enough room above).
///
/// The toolbar is installed as a subview of the text view's superview and
/// managed by the ``MarkdownEditorView/Coordinator``.
final class MarkdownFloatingToolbar: UIView {

    // MARK: - Properties

    /// The text view that receives formatting actions.
    private weak var textView: MarkdownTextView?

    /// Called when the user taps the "Insert Image" button.
    /// The coordinator handles presenting the image source picker.
    var onInsertImage: (() -> Void)?

    /// Undo button — disabled when nothing to undo.
    private let undoButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "arrow.uturn.backward"), for: .normal)
        button.tintColor = .label
        button.accessibilityLabel = "Undo"
        return button
    }()

    /// Redo button — disabled when nothing to redo.
    private let redoButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "arrow.uturn.forward"), for: .normal)
        button.tintColor = .label
        button.accessibilityLabel = "Redo"
        return button
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .center
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    /// Height of the toolbar in points.
    private static let toolbarHeight: CGFloat = 40

    /// Vertical gap between the selection rect and the toolbar.
    private static let verticalOffset: CGFloat = 6

    // MARK: - Init

    init(textView: MarkdownTextView) {
        self.textView = textView
        super.init(frame: .zero)
        configureAppearance()
        configureButtons()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configuration

    private func configureAppearance() {
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 10
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8

        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
        ])

        isHidden = true
        alpha = 0

        // Accessibility: group toolbar buttons so VoiceOver treats them as a unit.
        isAccessibilityElement = false
        accessibilityLabel = "Formatting toolbar"
    }

    private func configureButtons() {
        // Undo / Redo (left section, separated from formatting).
        undoButton.addTarget(self, action: #selector(undoTapped), for: .touchUpInside)
        redoButton.addTarget(self, action: #selector(redoTapped), for: .touchUpInside)
        stackView.addArrangedSubview(undoButton)
        stackView.addArrangedSubview(redoButton)

        // Thin vertical separator between undo/redo and formatting.
        let separator = UIView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = .separator
        separator.widthAnchor.constraint(equalToConstant: 1).isActive = true
        separator.heightAnchor.constraint(equalToConstant: 20).isActive = true
        separator.accessibilityElementsHidden = true
        stackView.addArrangedSubview(separator)

        // Formatting actions.
        let actions: [(String, String, Selector)] = [
            ("bold", "Bold", #selector(boldTapped)),
            ("italic", "Italic", #selector(italicTapped)),
            ("strikethrough", "Strikethrough", #selector(strikethroughTapped)),
            ("chevron.left.forwardslash.chevron.right", "Code", #selector(codeTapped)),
            ("link", "Link", #selector(linkTapped)),
            ("photo.badge.plus", "Insert Image", #selector(imageTapped)),
        ]

        for (icon, label, action) in actions {
            let button = UIButton(type: .system)
            button.setImage(UIImage(systemName: icon), for: .normal)
            button.tintColor = .label
            button.accessibilityLabel = label
            button.addTarget(self, action: action, for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }
    }

    // MARK: - Show / Hide

    /// Shows the toolbar above (or below) the current text selection.
    ///
    /// - Parameter animated: Whether to animate the appearance. Defaults to `true`.
    func showAboveSelection(animated: Bool = true) {
        guard let textView, let superview = textView.superview else { return }

        // Ensure the toolbar is added to the text view's superview.
        if self.superview !== superview {
            superview.addSubview(self)
        }

        let selectionRect = selectionRectInSuperview()
        guard selectionRect != .zero else {
            hide(animated: false)
            return
        }

        // Calculate toolbar width based on buttons and separators.
        let buttonCount = stackView.arrangedSubviews.filter { !($0.accessibilityElementsHidden) }.count
        let separatorCount = stackView.arrangedSubviews.count - buttonCount
        let toolbarWidth = CGFloat(buttonCount) * 44 + CGFloat(separatorCount) * 9 + 8
        let centerX = selectionRect.midX

        // Clamp horizontally to superview bounds.
        let halfWidth = toolbarWidth / 2
        let minX = max(8, centerX - halfWidth)
        let maxX = min(superview.bounds.width - 8, centerX + halfWidth)
        let clampedCenterX = (minX + maxX) / 2

        // Try placing above the selection; fall back to below.
        let aboveY = selectionRect.minY - Self.verticalOffset - Self.toolbarHeight
        let belowY = selectionRect.maxY + Self.verticalOffset
        let y = aboveY >= superview.safeAreaInsets.top ? aboveY : belowY

        frame = CGRect(
            x: clampedCenterX - toolbarWidth / 2,
            y: y,
            width: toolbarWidth,
            height: Self.toolbarHeight
        )

        guard isHidden || alpha < 1 else {
            updateUndoRedoState()
            return
        }
        isHidden = false
        updateUndoRedoState()

        if animated {
            UIView.animate(withDuration: 0.15) { [weak self] in
                self?.alpha = 1
            }
        } else {
            alpha = 1
        }
    }

    /// Hides the toolbar.
    ///
    /// - Parameter animated: Whether to animate the disappearance. Defaults to `true`.
    func hide(animated: Bool = true) {
        guard !isHidden else { return }

        if animated {
            UIView.animate(withDuration: 0.1, animations: { [weak self] in
                self?.alpha = 0
            }, completion: { [weak self] _ in
                self?.isHidden = true
            })
        } else {
            alpha = 0
            isHidden = true
        }
    }

    // MARK: - Private Helpers

    private func selectionRectInSuperview() -> CGRect {
        guard let textView,
              let superview = textView.superview,
              let selectedRange = textView.selectedTextRange,
              !selectedRange.isEmpty else { return .zero }

        let selectionRects = textView.selectionRects(for: selectedRange)
        guard !selectionRects.isEmpty else { return .zero }

        // Union all selection rects and convert to superview coordinates.
        var union = CGRect.zero
        for rect in selectionRects {
            union = union == .zero ? rect.rect : union.union(rect.rect)
        }
        return textView.convert(union, to: superview)
    }

    // MARK: - Actions

    @objc private func boldTapped() {
        textView?.formatBold()
    }

    @objc private func italicTapped() {
        textView?.formatItalic()
    }

    @objc private func strikethroughTapped() {
        textView?.formatStrikethrough()
    }

    @objc private func codeTapped() {
        textView?.formatCode()
    }

    @objc private func linkTapped() {
        textView?.formatLink()
    }

    @objc private func imageTapped() {
        onInsertImage?()
    }

    @objc private func undoTapped() {
        textView?.undoManager?.undo()
        updateUndoRedoState()
    }

    @objc private func redoTapped() {
        textView?.undoManager?.redo()
        updateUndoRedoState()
    }

    /// Updates the enabled state of the undo/redo buttons based on
    /// the text view's undo manager.
    func updateUndoRedoState() {
        let canUndo = textView?.undoManager?.canUndo ?? false
        let canRedo = textView?.undoManager?.canRedo ?? false
        undoButton.isEnabled = canUndo
        undoButton.tintColor = canUndo ? .label : .tertiaryLabel
        redoButton.isEnabled = canRedo
        redoButton.tintColor = canRedo ? .label : .tertiaryLabel
    }
}


// MARK: - MarkdownFixedToolbar

/// A Bear-style fixed toolbar that sits above the keyboard as an `inputAccessoryView`.
///
/// Per ADR-0002, the fixed toolbar provides persistent formatting access during
/// editing. It includes: Heading, List, Quote, Image, Bold, Italic, Strikethrough,
/// Code, Link, Undo, Redo.
///
/// When `showsDoneButton` is `true` (focus/fullscreen mode), a "Done" button is
/// shown to dismiss the editor. When `false` (standard mode), the toolbar provides
/// formatting controls only.
///
/// Managed by ``MarkdownEditorView/Coordinator``.
final class MarkdownFixedToolbar: UIView {

    // MARK: - Properties

    /// The text view that receives formatting actions.
    private weak var textView: MarkdownTextView?

    /// Called when the user taps the "Insert Image" button.
    var onInsertImage: (() -> Void)?

    /// Called when the user taps the "Done" button to dismiss focus mode.
    var onDismiss: (() -> Void)?

    /// Whether the Done button is visible (focus/fullscreen mode only).
    private let showsDoneButton: Bool

    /// Height of the toolbar in points.
    static let toolbarHeight: CGFloat = 44

    private let scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.alwaysBounceHorizontal = true
        return scroll
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 2
        stack.alignment = .center
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    /// Undo button — disabled when nothing to undo.
    private let undoButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "arrow.uturn.backward"), for: .normal)
        button.tintColor = .label
        button.accessibilityLabel = "Undo"
        return button
    }()

    /// Redo button — disabled when nothing to redo.
    private let redoButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "arrow.uturn.forward"), for: .normal)
        button.tintColor = .label
        button.accessibilityLabel = "Redo"
        return button
    }()

    /// Done button to dismiss focus mode.
    private let doneButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Done", for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .callout).bold()
        button.accessibilityLabel = "Done editing"
        return button
    }()

    // MARK: - Init

    init(textView: MarkdownTextView, showsDoneButton: Bool = true) {
        self.textView = textView
        self.showsDoneButton = showsDoneButton
        super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: Self.toolbarHeight))
        autoresizingMask = .flexibleWidth
        configureAppearance()
        configureButtons()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configuration

    private func configureAppearance() {
        backgroundColor = .secondarySystemGroupedBackground

        // Top border line.
        let border = UIView()
        border.translatesAutoresizingMaskIntoConstraints = false
        border.backgroundColor = .separator
        addSubview(border)

        addSubview(scrollView)
        scrollView.addSubview(stackView)

        var constraints = [
            border.topAnchor.constraint(equalTo: topAnchor),
            border.leadingAnchor.constraint(equalTo: leadingAnchor),
            border.trailingAnchor.constraint(equalTo: trailingAnchor),
            border.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale),

            scrollView.topAnchor.constraint(equalTo: border.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
        ]

        if showsDoneButton {
            // Done button sits outside the scroll view, pinned to the right.
            addSubview(doneButton)
            doneButton.translatesAutoresizingMaskIntoConstraints = false
            constraints.append(contentsOf: [
                scrollView.trailingAnchor.constraint(equalTo: doneButton.leadingAnchor, constant: -4),
                doneButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
                doneButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])
        } else {
            constraints.append(
                scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4)
            )
        }

        NSLayoutConstraint.activate(constraints)

        isAccessibilityElement = false
        accessibilityLabel = showsDoneButton ? "Formatting toolbar with Done button" : "Formatting toolbar"
    }

    private func configureButtons() {
        // Formatting actions (block-level + inline).
        let actions: [(String, String, Selector)] = [
            ("number", "Heading", #selector(headingTapped)),
            ("list.bullet", "List", #selector(listTapped)),
            ("text.quote", "Quote", #selector(quoteTapped)),
            ("bold", "Bold", #selector(boldTapped)),
            ("italic", "Italic", #selector(italicTapped)),
            ("strikethrough", "Strikethrough", #selector(strikethroughTapped)),
            ("chevron.left.forwardslash.chevron.right", "Code", #selector(codeTapped)),
            ("link", "Link", #selector(linkTapped)),
            ("photo.badge.plus", "Insert Image", #selector(imageTapped)),
        ]

        for (icon, label, action) in actions {
            let button = UIButton(type: .system)
            button.setImage(UIImage(systemName: icon), for: .normal)
            button.tintColor = .label
            button.accessibilityLabel = label
            button.addTarget(self, action: action, for: .touchUpInside)
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            stackView.addArrangedSubview(button)
        }

        // Thin vertical separator before undo/redo.
        let separator = UIView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = .separator
        separator.widthAnchor.constraint(equalToConstant: 1).isActive = true
        separator.heightAnchor.constraint(equalToConstant: 20).isActive = true
        separator.accessibilityElementsHidden = true
        stackView.addArrangedSubview(separator)

        // Undo / Redo.
        undoButton.addTarget(self, action: #selector(undoTapped), for: .touchUpInside)
        redoButton.addTarget(self, action: #selector(redoTapped), for: .touchUpInside)
        undoButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        undoButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        redoButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        redoButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        stackView.addArrangedSubview(undoButton)
        stackView.addArrangedSubview(redoButton)

        // Done button (focus mode only).
        if showsDoneButton {
            doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        }
    }

    // MARK: - Actions

    @objc private func headingTapped() {
        textView?.formatHeading()
    }

    @objc private func listTapped() {
        textView?.formatListItem()
    }

    @objc private func quoteTapped() {
        textView?.formatQuote()
    }

    @objc private func boldTapped() {
        textView?.formatBold()
    }

    @objc private func italicTapped() {
        textView?.formatItalic()
    }

    @objc private func strikethroughTapped() {
        textView?.formatStrikethrough()
    }

    @objc private func codeTapped() {
        textView?.formatCode()
    }

    @objc private func linkTapped() {
        textView?.formatLink()
    }

    @objc private func imageTapped() {
        onInsertImage?()
    }

    @objc private func undoTapped() {
        textView?.undoManager?.undo()
        updateUndoRedoState()
    }

    @objc private func redoTapped() {
        textView?.undoManager?.redo()
        updateUndoRedoState()
    }

    @objc private func doneTapped() {
        onDismiss?()
    }

    /// Updates the enabled state of the undo/redo buttons.
    func updateUndoRedoState() {
        let canUndo = textView?.undoManager?.canUndo ?? false
        let canRedo = textView?.undoManager?.canRedo ?? false
        undoButton.isEnabled = canUndo
        undoButton.tintColor = canUndo ? .label : .tertiaryLabel
        redoButton.isEnabled = canRedo
        redoButton.tintColor = canRedo ? .label : .tertiaryLabel
    }
}

/// UIFont extension for bold variant.
private extension UIFont {
    func bold() -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(.traitBold) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }
}


// MARK: - MarkdownTagCompletionView

/// A compact dropdown that shows tag autocompletion suggestions below the
/// cursor when the user types `#` followed by characters.
///
/// Each row displays the tag name and optional usage count. Tapping a tag
/// replaces the `#prefix` in the editor with the full `#tagName`.
///
/// Managed by ``MarkdownEditorView/Coordinator``.
final class MarkdownTagCompletionView: UIView {

    // MARK: Properties

    private weak var textView: MarkdownTextView?
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    /// Maximum number of suggestions to display.
    private static let maxSuggestions = 5

    /// Called when a tag is selected. The string is the full tag name (without `#`).
    var onTagSelected: ((String) -> Void)?

    // MARK: Init

    init(textView: MarkdownTextView) {
        self.textView = textView
        super.init(frame: .zero)
        configureAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Configuration

    private func configureAppearance() {
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 8
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 6
        clipsToBounds = false
        isHidden = true
        alpha = 0

        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])

        isAccessibilityElement = false
        accessibilityLabel = "Tag suggestions"
    }

    // MARK: Update

    /// Updates the displayed tags and repositions the popup near the cursor.
    ///
    /// - Parameter tags: The matching tags to display (max ``maxSuggestions``).
    func showTags(_ tags: [MarkdownTag]) {
        guard let textView, let superview = textView.superview, !tags.isEmpty else {
            hide()
            return
        }

        // Ensure we're added to the superview.
        if self.superview !== superview {
            superview.addSubview(self)
        }

        // Rebuild tag rows.
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let displayTags = Array(tags.prefix(Self.maxSuggestions))
        for tag in displayTags {
            let row = createTagRow(tag)
            stackView.addArrangedSubview(row)
        }

        // Position below the cursor.
        let cursorRect = cursorRectInSuperview()
        guard cursorRect != .zero else {
            hide()
            return
        }

        let rowHeight: CGFloat = 36
        let padding: CGFloat = 8
        let height = CGFloat(displayTags.count) * rowHeight + padding
        let width: CGFloat = 200

        let x = max(8, min(cursorRect.minX, superview.bounds.width - width - 8))
        let y = cursorRect.maxY + 4

        frame = CGRect(x: x, y: y, width: width, height: height)

        guard isHidden || alpha < 1 else { return }
        isHidden = false
        UIView.animate(withDuration: 0.12) { [weak self] in
            self?.alpha = 1
        }
    }

    /// Hides the completion popup.
    func hide() {
        guard !isHidden else { return }
        UIView.animate(withDuration: 0.08, animations: { [weak self] in
            self?.alpha = 0
        }, completion: { [weak self] _ in
            self?.isHidden = true
        })
    }

    // MARK: Private Helpers

    private func cursorRectInSuperview() -> CGRect {
        guard let textView, let superview = textView.superview else { return .zero }
        let caretRect = textView.caretRect(for: textView.selectedTextRange?.start ?? textView.beginningOfDocument)
        return textView.convert(caretRect, to: superview)
    }

    private func createTagRow(_ tag: MarkdownTag) -> UIView {
        let container = UIButton(type: .system)
        container.contentHorizontalAlignment = .leading

        let nameLabel = UILabel()
        nameLabel.text = "#\(tag.name)"
        nameLabel.font = .preferredFont(forTextStyle: .callout)
        nameLabel.textColor = .label
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let countLabel = UILabel()
        countLabel.text = tag.usageCount > 0 ? "\(tag.usageCount)" : nil
        countLabel.font = .preferredFont(forTextStyle: .caption2)
        countLabel.textColor = .secondaryLabel
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [nameLabel, countLabel])
        row.axis = .horizontal
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        row.isUserInteractionEnabled = false

        container.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            row.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            row.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            container.heightAnchor.constraint(equalToConstant: 36),
        ])

        container.accessibilityLabel = "Tag: \(tag.name)"
        if tag.usageCount > 0 {
            container.accessibilityValue = "Used \(tag.usageCount) times"
        }

        let tagName = tag.name
        container.addAction(UIAction { [weak self] _ in
            self?.onTagSelected?(tagName)
        }, for: .touchUpInside)

        return container
    }
}

// MARK: - MarkdownEditorView

/// A SwiftUI Markdown editor with live syntax highlighting and context-menu
/// formatting.
///
/// Wraps a ``MarkdownTextView`` (a `UITextView` subclass) backed by
/// ``MarkdownTextStorage`` to apply colour-coded formatting to Markdown
/// syntax in real time. Formatting actions (Bold, Italic, Code, Link,
/// Strikethrough, List, Heading) are available in the standard iOS edit
/// menu — the same callout where Cut / Copy / Paste appear.
///
/// ```swift
/// @State private var text = "# Hello\n**bold** and *italic*"
/// MarkdownEditorView(text: $text)
/// ```
///
/// Optionally supply a ``MarkdownTheme`` to customise the editor colours:
///
/// ```swift
/// MarkdownEditorView(text: $text, theme: .defaultDark)
/// ```
///
/// - Note: Requires iOS / iPadOS (UIKit).
public struct MarkdownEditorView: UIViewRepresentable {

    // MARK: Properties

    @Binding public var text: String

    /// Colour theme for syntax highlighting. Defaults to ``MarkdownTheme/default``.
    public var theme: MarkdownTheme = .default

    /// Minimum height of the text view in points.
    public var minHeight: CGFloat = 120

    /// When `true`, enables Bear-style Live Preview: inactive blocks hide
    /// control characters and render formatted text (per ADR-0004).
    /// Defaults to `true`.
    public var livePreviewEnabled: Bool = true

    /// Placeholder text shown when the editor is empty.
    /// When `nil`, no placeholder is displayed.
    public var placeholder: String?

    /// When `true`, a Notion-style floating toolbar appears above the text
    /// selection with quick access to formatting actions (Bold, Italic,
    /// Strikethrough, Code, Link). Per ADR-0002 Phase 1.
    /// Defaults to `false` — the fixed toolbar above the keyboard is used instead,
    /// following the Bear markdown editor approach.
    public var showsFloatingToolbar: Bool = false

    /// Called when the active (cursor-containing) Markdown block changes.
    ///
    /// Receives the zero-based block index into the ``MarkdownBlockParser/parse(_:)``
    /// result, or `nil` when the cursor is outside all blocks (empty document).
    /// Use this for live preview: render inactive blocks while showing raw
    /// syntax for the active one.
    private let onActiveBlockChange: ((Int?) -> Void)?

    /// Optional tag provider for autocompletion when typing `#` in the editor.
    ///
    /// When set, a dropdown with matching tags appears as the user types `#`
    /// followed by characters. Per ADR-0008.
    private let tagProvider: (any MarkdownTagProvider)?

    /// Optional delegate for image insertion.
    ///
    /// When set, an "Insert Image" button appears in the toolbar and context menu.
    /// The delegate is called to store images selected from the photo library.
    /// Per ADR-0007.
    private let imageInsertionDelegate: (any MarkdownImageInsertionDelegate)?

    /// When `true`, enables fullscreen/focus mode. The fixed toolbar above the
    /// keyboard includes a "Done" button to dismiss focus mode (per ADR-0002).
    /// Defaults to `false`.
    public var focusModeEnabled: Bool = false

    /// When `true`, disables live preview and always shows raw Markdown syntax
    /// with full highlighting (Pro Mode per AK-066).
    ///
    /// Overrides ``livePreviewEnabled`` — when Pro Mode is on, all blocks
    /// display their control characters regardless of the live preview setting.
    /// Defaults to `false`.
    public var proModeEnabled: Bool = false

    /// Called when the user taps "Done" on the fixed toolbar to dismiss focus mode.
    private let onDismissFocusMode: (() -> Void)?

    /// When `true` (default), the underlying `UITextView` manages its own
    /// vertical scrolling. When `false`, scrolling is disabled and the text
    /// view grows to fit its content — useful when the editor is embedded in
    /// an outer `ScrollView` that should own the scroll behaviour.
    public var isScrollEnabled: Bool = true

    @Environment(\.colorScheme) private var colorScheme

    /// Creates a Markdown editor view.
    ///
    /// - Parameters:
    ///   - text: Binding to the Markdown text being edited.
    ///   - theme: Colour theme for syntax highlighting. Defaults to ``MarkdownTheme/default``.
    ///   - minHeight: Minimum height of the text view in points. Defaults to `120`.
    ///   - livePreviewEnabled: Whether to enable Bear-style live preview (default `true`).
    ///   - placeholder: Optional placeholder text shown when the editor is empty.
    ///   - showsFloatingToolbar: Whether to show the floating formatting toolbar on text
    ///     selection (default `false`). Per ADR-0002, the formatting toolbar is now anchored
    ///     above the keyboard instead.
    ///   - focusModeEnabled: Whether to enable fullscreen focus mode with a fixed toolbar
    ///     above the keyboard (default `false`). Per ADR-0002 Phase 2.
    ///   - proModeEnabled: Whether to enable Pro Mode (raw Markdown always visible,
    ///     overrides live preview). Defaults to `false`. Per AK-066.
    ///   - tagProvider: Optional provider for tag autocompletion. When set, a dropdown
    ///     with matching tags appears when the user types `#`. Per ADR-0008.
    ///   - imageInsertionDelegate: Optional delegate for image insertion. When set, an
    ///     "Insert Image" button appears in the toolbar and context menu. Per ADR-0007.
    ///   - onDismissFocusMode: Called when the user taps "Done" on the fixed toolbar.
    ///   - onActiveBlockChange: Optional callback fired when the cursor moves into a
    ///     different block. Receives the block index or `nil`.
    public init(
        text: Binding<String>,
        theme: MarkdownTheme = .default,
        minHeight: CGFloat = 120,
        livePreviewEnabled: Bool = true,
        placeholder: String? = nil,
        showsFloatingToolbar: Bool = false,
        focusModeEnabled: Bool = false,
        proModeEnabled: Bool = false,
        isScrollEnabled: Bool = true,
        tagProvider: (any MarkdownTagProvider)? = nil,
        imageInsertionDelegate: (any MarkdownImageInsertionDelegate)? = nil,
        onDismissFocusMode: (() -> Void)? = nil,
        onActiveBlockChange: ((Int?) -> Void)? = nil
    ) {
        self._text = text
        self.theme = theme
        self.minHeight = minHeight
        self.livePreviewEnabled = livePreviewEnabled
        self.placeholder = placeholder
        self.showsFloatingToolbar = showsFloatingToolbar
        self.focusModeEnabled = focusModeEnabled
        self.proModeEnabled = proModeEnabled
        self.isScrollEnabled = isScrollEnabled
        self.tagProvider = tagProvider
        self.imageInsertionDelegate = imageInsertionDelegate
        self.onDismissFocusMode = onDismissFocusMode
        self.onActiveBlockChange = onActiveBlockChange
    }

    // MARK: UIViewRepresentable

    public func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            tagProvider: tagProvider,
            imageInsertionDelegate: imageInsertionDelegate,
            onActiveBlockChange: onActiveBlockChange
        )
    }

    /// Creates and configures the underlying ``MarkdownTextView`` with a
    /// ``MarkdownTextStorage`` for live syntax highlighting.
    ///
    /// - Parameter context: The representable context provided by SwiftUI.
    /// - Returns: A configured ``MarkdownTextView`` instance.
    public func makeUIView(context: Context) -> MarkdownTextView {
        let storage = MarkdownTextStorage()
        storage.theme = theme
        storage.colorScheme = colorScheme == .dark ? .dark : .light
        storage.livePreviewEnabled = livePreviewEnabled
        storage.proModeEnabled = proModeEnabled

        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)

        let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)

        let textView = MarkdownTextView(frame: .zero, textContainer: container)
        textView.delegate = context.coordinator
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.isScrollEnabled = isScrollEnabled
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .yes
        textView.spellCheckingType = .yes
        textView.smartDashesType = .no   // Prevent em-dash substitution in Markdown
        textView.smartQuotesType = .no  // Prevent curly quotes in Markdown
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.accessibilityLabel = "Markdown editor"
        textView.accessibilityHint = "Edit formatted text using Markdown syntax"

        // Placeholder label — hidden when text is non-empty.
        if let placeholder {
            let label = UILabel()
            label.text = placeholder
            label.font = .preferredFont(forTextStyle: .body)
            label.textColor = .tertiaryLabel
            label.numberOfLines = 0
            label.translatesAutoresizingMaskIntoConstraints = false
            label.tag = Self.placeholderTag
            label.isAccessibilityElement = false
            textView.addSubview(label)
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: textView.topAnchor, constant: 8),
                label.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 8),
                label.trailingAnchor.constraint(lessThanOrEqualTo: textView.trailingAnchor, constant: -8),
            ])
            label.isHidden = !text.isEmpty
        }

        // Give the coordinator a weak reference for Dynamic Type rehighlighting.
        context.coordinator.textView = textView

        // Wire the image insertion callback from context menu → coordinator.
        textView.onInsertImageRequested = { [weak coordinator = context.coordinator] in
            coordinator?.presentImageSourcePicker()
        }

        // Always attach the fixed toolbar as a keyboard accessory (Bear-style).
        // In focus mode it includes a Done button; otherwise it omits it.
        let fixedToolbar = MarkdownFixedToolbar(textView: textView, showsDoneButton: focusModeEnabled)
        fixedToolbar.onInsertImage = { [weak coordinator = context.coordinator] in
            coordinator?.presentImageSourcePicker()
        }
        fixedToolbar.onDismiss = focusModeEnabled ? onDismissFocusMode : nil
        textView.inputAccessoryView = fixedToolbar
        context.coordinator.fixedToolbar = fixedToolbar

        return textView
    }

    /// Tag used to identify the placeholder UILabel inside the text view.
    private static let placeholderTag = 9_999

    /// Synchronises the SwiftUI binding with the text view, updating content
    /// and theme only when values have changed to avoid cursor jumps.
    ///
    /// - Parameters:
    ///   - uiView: The ``MarkdownTextView`` to update.
    ///   - context: The representable context provided by SwiftUI.
    public func updateUIView(_ uiView: MarkdownTextView, context: Context) {
        guard let storage = uiView.textStorage as? MarkdownTextStorage else { return }

        // Only replace content when the binding value differs from the view's text,
        // preventing cursor jumps during every render pass.
        if uiView.text != text {
            let selectedRange = uiView.selectedRange
            storage.setMarkdownString(text)
            // Restore cursor, clamped to the new length.
            let clampedLocation = min(selectedRange.location, storage.length)
            uiView.selectedRange = NSRange(location: clampedLocation, length: 0)
        }

        // Keep theme in sync (category switching, dark/light mode change).
        if storage.theme != theme {
            storage.theme = theme
        }

        // Keep color scheme in sync (Light ↔ Dark mode transitions).
        let resolved: MarkdownTheme.ColorScheme = colorScheme == .dark ? .dark : .light
        if storage.colorScheme != resolved {
            storage.colorScheme = resolved
        }

        // Keep live preview mode in sync.
        if storage.livePreviewEnabled != livePreviewEnabled {
            storage.livePreviewEnabled = livePreviewEnabled
        }

        // Keep Pro Mode in sync.
        if storage.proModeEnabled != proModeEnabled {
            storage.proModeEnabled = proModeEnabled
        }

        // Keep scroll enablement in sync (allows toggling at runtime).
        if uiView.isScrollEnabled != isScrollEnabled {
            uiView.isScrollEnabled = isScrollEnabled
        }

        // When the text view manages its own height (scrolling disabled) the
        // intrinsic content size must be invalidated whenever the text content
        // changes so that SwiftUI re-queries `sizeThatFits` and expands the
        // frame to fit the full text — not just the initial snapshot.
        if !isScrollEnabled {
            uiView.invalidateIntrinsicContentSize()
        }

        // Toggle placeholder visibility.
        if let label = uiView.viewWithTag(Self.placeholderTag) {
            label.isHidden = !text.isEmpty
        }

        // Keep floating toolbar preference in sync.
        // In focus mode, the floating toolbar is hidden (fixed toolbar replaces it).
        context.coordinator.showsFloatingToolbar = showsFloatingToolbar && !focusModeEnabled
    }

    /// Returns the preferred size for the text view.
    ///
    /// When `isScrollEnabled` is `false` the text view does not scroll and must
    /// size itself to fit all of its content. This implementation returns `nil`
    /// when scrolling is enabled (letting SwiftUI fill the available space) and
    /// returns the UIKit content size when scrolling is disabled, so the outer
    /// `ScrollView` can expand to show every line of text.
    public func sizeThatFits(_ proposal: ProposedViewSize, uiView: MarkdownTextView, context: Context) -> CGSize? {
        guard !isScrollEnabled else { return nil }
        let width = proposal.width ?? uiView.bounds.width
        guard width > 0 else { return nil }
        let fittingSize = CGSize(width: width, height: .greatestFiniteMagnitude)
        let needed = uiView.sizeThatFits(fittingSize)
        return CGSize(width: width, height: max(minHeight, needed.height))
    }

    // MARK: - Coordinator

    public final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        private let onActiveBlockChange: ((Int?) -> Void)?
        private let tagProvider: (any MarkdownTagProvider)?
        private let imageInsertionDelegate: (any MarkdownImageInsertionDelegate)?
        private var lastActiveBlock: Int?
        private var contentSizeObserver: (any NSObjectProtocol)?

        /// The floating formatting toolbar, created lazily when text is first selected.
        private var floatingToolbar: MarkdownFloatingToolbar?

        /// The fixed toolbar, used in focus mode (set during `makeUIView`).
        var fixedToolbar: MarkdownFixedToolbar?

        /// The tag autocompletion popup, created lazily when `#` is typed.
        private var tagCompletionView: MarkdownTagCompletionView?

        /// Whether the floating toolbar is enabled (controlled by the parent view).
        var showsFloatingToolbar: Bool = true

        /// Active tag completion task (cancelled when prefix changes).
        private var tagCompletionTask: Task<Void, Never>?

        init(
            text: Binding<String>,
            tagProvider: (any MarkdownTagProvider)?,
            imageInsertionDelegate: (any MarkdownImageInsertionDelegate)?,
            onActiveBlockChange: ((Int?) -> Void)?
        ) {
            self.text = text
            self.tagProvider = tagProvider
            self.imageInsertionDelegate = imageInsertionDelegate
            self.onActiveBlockChange = onActiveBlockChange
            super.init()

            // Observe Dynamic Type changes so the editor re-highlights with
            // updated font sizes when the user changes the system text size.
            contentSizeObserver = NotificationCenter.default.addObserver(
                forName: UIContentSizeCategory.didChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleContentSizeCategoryChange()
            }
        }

        deinit {
            if let observer = contentSizeObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        /// Weak reference to the text view, set during `makeUIView` and updated
        /// in `updateUIView`. Used to trigger rehighlight on Dynamic Type changes.
        weak var textView: MarkdownTextView?

        /// Forwards text changes from the `UITextView` back to the SwiftUI binding.
        ///
        /// Also invalidates the intrinsic content size when the text view has
        /// scrolling disabled so that the parent SwiftUI layout picks up the
        /// new height without requiring an explicit state update.
        ///
        /// - Parameter textView: The text view that changed.
        public func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text
            if !textView.isScrollEnabled {
                textView.invalidateIntrinsicContentSize()
            }
            notifyActiveBlockIfNeeded(textView)
            updateFloatingToolbar(textView)
            updateTagCompletion(textView)
            fixedToolbar?.updateUndoRedoState()
        }

        /// Fires when the cursor position or selection changes.
        ///
        /// - Parameter textView: The text view whose selection changed.
        public func textViewDidChangeSelection(_ textView: UITextView) {
            notifyActiveBlockIfNeeded(textView)
            updateFloatingToolbar(textView)
            updateTagCompletion(textView)
        }

        /// Computes the active block index and fires the callback if it changed.
        private func notifyActiveBlockIfNeeded(_ textView: UITextView) {
            let cursorOffset = textView.selectedRange.location
            let markdown = textView.text ?? ""
            let activeBlock = MarkdownBlockParser.blockIndex(at: cursorOffset, in: markdown)

            if activeBlock != lastActiveBlock {
                lastActiveBlock = activeBlock
                onActiveBlockChange?(activeBlock)

                // Push active block to storage for live preview rendering.
                if let storage = textView.textStorage as? MarkdownTextStorage,
                   storage.livePreviewEnabled {
                    // Animate the transition between blocks with a smooth crossfade
                    // so syntax characters fade in/out instead of snapping.
                    UIView.transition(
                        with: textView,
                        duration: 0.15,
                        options: [.transitionCrossDissolve, .allowUserInteraction]
                    ) {
                        storage.activeBlockIndex = activeBlock
                    }
                }
            }
        }

        /// Re-highlights the text storage when the system content size category
        /// changes (Dynamic Type), so that all fonts update to match the new size.
        private func handleContentSizeCategoryChange() {
            guard let textView,
                  let storage = textView.textStorage as? MarkdownTextStorage else { return }
            storage.rehighlight()
        }

        // MARK: - Floating Toolbar

        /// Shows or hides the floating toolbar based on the current selection.
        private func updateFloatingToolbar(_ textView: UITextView) {
            guard showsFloatingToolbar,
                  let markdownTextView = textView as? MarkdownTextView else {
                floatingToolbar?.hide()
                return
            }

            let hasSelection = textView.selectedRange.length > 0

            if hasSelection {
                // Create the toolbar on first use.
                if floatingToolbar == nil {
                    let toolbar = MarkdownFloatingToolbar(textView: markdownTextView)
                    toolbar.onInsertImage = { [weak self] in
                        self?.presentImageSourcePicker()
                    }
                    floatingToolbar = toolbar
                }
                floatingToolbar?.showAboveSelection()
            } else {
                floatingToolbar?.hide()
            }
        }

        // MARK: - Tag Autocompletion

        /// Checks if the cursor is inside a `#tag` prefix and shows/hides the
        /// tag autocompletion popup accordingly.
        private func updateTagCompletion(_ textView: UITextView) {
            guard let tagProvider,
                  let markdownTextView = textView as? MarkdownTextView else {
                tagCompletionView?.hide()
                return
            }

            // Don't show completion when text is selected.
            guard textView.selectedRange.length == 0 else {
                tagCompletionView?.hide()
                return
            }

            let cursorOffset = textView.selectedRange.location
            let fullText = textView.text ?? ""

            guard let tagPrefix = extractTagPrefix(at: cursorOffset, in: fullText) else {
                tagCompletionView?.hide()
                tagCompletionTask?.cancel()
                return
            }

            let prefix = tagPrefix.prefix
            let replaceRange = tagPrefix.range

            // Cancel any in-flight completion request.
            tagCompletionTask?.cancel()

            tagCompletionTask = Task { @MainActor [weak self] in
                guard let self else { return }
                let tags = await tagProvider.availableTags(matching: prefix)
                guard !Task.isCancelled else { return }

                if tags.isEmpty {
                    self.tagCompletionView?.hide()
                    return
                }

                // Create completion view on first use.
                if self.tagCompletionView == nil {
                    self.tagCompletionView = MarkdownTagCompletionView(textView: markdownTextView)
                }

                // Update the selection handler with the current range
                // (range changes each time the prefix changes).
                self.tagCompletionView?.onTagSelected = { [weak self] tagName in
                    self?.insertTag(tagName, replacingRange: replaceRange, in: markdownTextView)
                }

                self.tagCompletionView?.showTags(tags)
            }
        }

        /// Inserts a tag by replacing the `#prefix` range with `#fullTagName `.
        private func insertTag(_ tagName: String, replacingRange range: NSRange, in textView: MarkdownTextView) {
            let replacement = "#\(tagName) "
            guard let start = textView.position(from: textView.beginningOfDocument, offset: range.location),
                  let end = textView.position(from: start, offset: range.length),
                  let replaceRange = textView.textRange(from: start, to: end) else { return }

            textView.replace(replaceRange, withText: replacement)
            tagCompletionView?.hide()
        }

        // MARK: - Image Insertion

        /// Presents an action sheet to choose the image source (Photo Library or URL).
        func presentImageSourcePicker() {
            guard let textView else { return }
            guard let viewController = textView.closestViewController else { return }

            let alert = UIAlertController(
                title: "Insert Image",
                message: nil,
                preferredStyle: .actionSheet
            )

            // Only show Photo Library option if a delegate is available.
            if imageInsertionDelegate != nil {
                alert.addAction(UIAlertAction(title: "Photo Library", style: .default) { [weak self] _ in
                    self?.presentPhotoPicker()
                })
            }

            alert.addAction(UIAlertAction(title: "From URL", style: .default) { [weak self] _ in
                self?.presentURLInput()
            })

            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

            // iPad popover anchor.
            if let popover = alert.popoverPresentationController {
                let caretRect = textView.caretRect(
                    for: textView.selectedTextRange?.start ?? textView.beginningOfDocument
                )
                popover.sourceView = textView
                popover.sourceRect = caretRect
            }

            viewController.present(alert, animated: true)
        }

        /// Presents a URL input dialog for inserting an image from a URL.
        private func presentURLInput() {
            guard let textView else { return }
            guard let viewController = textView.closestViewController else { return }

            let alert = UIAlertController(
                title: "Insert Image from URL",
                message: "Enter the image URL and optional description.",
                preferredStyle: .alert
            )

            alert.addTextField { field in
                field.placeholder = "https://example.com/image.jpg"
                field.keyboardType = .URL
                field.autocapitalizationType = .none
                field.autocorrectionType = .no
                field.accessibilityLabel = "Image URL"
            }

            alert.addTextField { field in
                field.placeholder = "Description (optional)"
                field.accessibilityLabel = "Image description"
            }

            alert.addAction(UIAlertAction(title: "Insert", style: .default) { [weak self, weak alert] _ in
                guard let self, let alert else { return }
                let urlText = alert.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let altText = alert.textFields?[1].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                guard !urlText.isEmpty else { return }
                let syntax = markdownImageSyntax(url: urlText, altText: altText)
                self.insertTextAtCursor(syntax)
                UIAccessibility.post(notification: .announcement, argument: "Image inserted")
            })

            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

            viewController.present(alert, animated: true)
        }

        /// Presents the photo library picker via `PHPickerViewController`.
        private func presentPhotoPicker() {
            guard let textView else { return }
            guard let viewController = textView.closestViewController else { return }

            var config = PHPickerConfiguration()
            config.filter = .images
            config.selectionLimit = 1

            let picker = PHPickerViewController(configuration: config)
            picker.delegate = self
            viewController.present(picker, animated: true)
        }

        /// Inserts text at the current cursor position in the text view.
        private func insertTextAtCursor(_ text: String) {
            guard let textView, let range = textView.selectedTextRange else { return }
            textView.replace(range, withText: text + "\n")
        }
    }
}

// MARK: - PHPickerViewControllerDelegate

extension MarkdownEditorView.Coordinator: PHPickerViewControllerDelegate {

    /// Handles the user's photo library selection.
    ///
    /// Loads the selected image data, calls the ``MarkdownImageInsertionDelegate``
    /// to store it, and inserts the Markdown image syntax at the cursor.
    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let result = results.first,
              let imageInsertionDelegate else { return }

        let itemProvider = result.itemProvider
        guard itemProvider.canLoadObject(ofClass: UIImage.self) else { return }

        itemProvider.loadDataRepresentation(forTypeIdentifier: "public.image") { [weak self] data, error in
            guard let self, let data, error == nil else { return }

            Task { @MainActor [weak self] in
                guard let self else { return }
                let filename = suggestedPhotoFilename()
                if let url = await imageInsertionDelegate.storeImage(data, suggestedName: filename) {
                    let syntax = markdownImageSyntax(url: url, altText: "Photo")
                    self.insertTextAtCursor(syntax)
                    UIAccessibility.post(notification: .announcement, argument: "Photo inserted")
                }
            }
        }
    }
}

// MARK: - MarkdownFocusEditorView

/// A fullscreen Markdown editor with a Bear-style fixed toolbar above the keyboard.
///
/// Per ADR-0002 Phase 2, the focus mode provides persistent formatting access via
/// ``MarkdownFixedToolbar``. The floating toolbar is automatically hidden in this mode.
///
/// Usage:
/// ```swift
/// @State private var text = "# Hello"
/// @State private var showingFocusEditor = false
///
/// Button("Edit") { showingFocusEditor = true }
///     .fullScreenCover(isPresented: $showingFocusEditor) {
///         MarkdownFocusEditorView(text: $text)
///     }
/// ```
///
/// The view can also be presented modally or pushed in a NavigationStack.
///
/// - SeeAlso: ``MarkdownEditorView`` for the standard (non-focus) editor.
/// - SeeAlso: ADR-0002 for the three-layer formatting UI strategy.
public struct MarkdownFocusEditorView: View {

    /// Binding to the Markdown text being edited.
    @Binding public var text: String

    /// Colour theme for syntax highlighting.
    public var theme: MarkdownTheme = .default

    /// Whether to enable Bear-style live preview.
    public var livePreviewEnabled: Bool = true

    /// Optional tag provider for autocompletion.
    private let tagProvider: (any MarkdownTagProvider)?

    /// Optional delegate for image insertion.
    private let imageInsertionDelegate: (any MarkdownImageInsertionDelegate)?

    /// Called when the active block changes.
    private let onActiveBlockChange: ((Int?) -> Void)?

    @Environment(\.dismiss) private var dismiss

    /// Creates a fullscreen focus mode Markdown editor.
    ///
    /// - Parameters:
    ///   - text: Binding to the Markdown text being edited.
    ///   - theme: Colour theme for syntax highlighting. Defaults to ``MarkdownTheme/default``.
    ///   - livePreviewEnabled: Whether to enable live preview (default `true` in focus mode).
    ///   - tagProvider: Optional provider for tag autocompletion.
    ///   - imageInsertionDelegate: Optional delegate for image insertion.
    ///   - onActiveBlockChange: Optional callback fired when the cursor moves between blocks.
    public init(
        text: Binding<String>,
        theme: MarkdownTheme = .default,
        livePreviewEnabled: Bool = true,
        tagProvider: (any MarkdownTagProvider)? = nil,
        imageInsertionDelegate: (any MarkdownImageInsertionDelegate)? = nil,
        onActiveBlockChange: ((Int?) -> Void)? = nil
    ) {
        self._text = text
        self.theme = theme
        self.livePreviewEnabled = livePreviewEnabled
        self.tagProvider = tagProvider
        self.imageInsertionDelegate = imageInsertionDelegate
        self.onActiveBlockChange = onActiveBlockChange
    }

    public var body: some View {
        MarkdownEditorView(
            text: $text,
            theme: theme,
            livePreviewEnabled: livePreviewEnabled,
            showsFloatingToolbar: false,
            focusModeEnabled: true,
            tagProvider: tagProvider,
            imageInsertionDelegate: imageInsertionDelegate,
            onDismissFocusMode: { dismiss() },
            onActiveBlockChange: onActiveBlockChange
        )
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .accessibilityLabel("Focus mode editor")
    }
}

#Preview("Markdown Editor") {
    struct PreviewWrapper: View {
        @State private var text = """
        # Plan für Amsterdam 🌷

        ## 📍 Ort
        Rijksmuseum, Museumstraat 1, 1071 XX Amsterdam

        ## ⏱️ Öffnungszeiten
        Täglich **09:00–17:00 Uhr**

        ## 💶 Eintritt
        - Erwachsene: `€22,50`
        - Kinder (bis 18): *kostenlos*

        ## 🔗 Links
        [Tickets kaufen](https://www.rijksmuseum.nl)

        ## 📝 Notizen
        > Unbedingt Nachts im Museum – Online-Ticket lohnt sich!

        - [x] Tickets gebucht
        - [ ] Audioguide reservieren
        """

        var body: some View {
            VStack(spacing: 0) {
                MarkdownEditorView(text: $text)
            }
            .navigationTitle("Markdown Editor")
        }
    }

    return NavigationStack { PreviewWrapper() }
}

#endif
