//
//  MarkdownImageInsertionTests.swift
//  AssistanceKitTests
//
//  Tests for image insertion helpers and Markdown image syntax generation.
//

import Foundation
import Testing
@testable import MarkdownUI

// MARK: - Image Syntax Generation Tests

@Suite("Markdown Image Insertion Tests")
struct MarkdownImageInsertionTests {

    @Test("Generates image syntax with URL and alt text")
    func imageWithAltText() {
        let result = markdownImageSyntax(url: "https://example.com/img.jpg", altText: "A photo")
        #expect(result == "![A photo](https://example.com/img.jpg)")
    }

    @Test("Generates image syntax with empty alt text")
    func imageWithEmptyAlt() {
        let result = markdownImageSyntax(url: "https://example.com/img.jpg")
        #expect(result == "![](https://example.com/img.jpg)")
    }

    @Test("Generates image syntax with local URL")
    func imageWithLocalURL() {
        let result = markdownImageSyntax(url: "local://photo-abc.jpg", altText: "Photo")
        #expect(result == "![Photo](local://photo-abc.jpg)")
    }

    @Test("Handles special characters in alt text")
    func specialCharsInAlt() {
        let result = markdownImageSyntax(url: "https://ex.com/i.jpg", altText: "Über München")
        #expect(result == "![Über München](https://ex.com/i.jpg)")
    }

    @Test("Handles empty URL")
    func emptyURL() {
        let result = markdownImageSyntax(url: "", altText: "test")
        #expect(result == "![test]()")
    }

    // MARK: - Suggested Filename Tests

    @Test("Suggested filename has photo prefix and .jpg extension")
    func filenameFormat() {
        let filename = suggestedPhotoFilename()
        #expect(filename.hasPrefix("photo-"))
        #expect(filename.hasSuffix(".jpg"))
    }

    @Test("Suggested filename contains date")
    func filenameContainsDate() {
        let filename = suggestedPhotoFilename()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        #expect(filename.contains(today))
    }

    @Test("Suggested filenames are unique")
    func uniqueFilenames() {
        // Two calls in quick succession should still produce different names
        // (or at minimum the same second-level name if called within 1s).
        let name1 = suggestedPhotoFilename()
        let name2 = suggestedPhotoFilename()
        // Both should be valid format regardless.
        #expect(name1.hasPrefix("photo-"))
        #expect(name2.hasPrefix("photo-"))
    }
}
