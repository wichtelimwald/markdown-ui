//
//  MarkdownTagProviderTests.swift
//  AssistanceKit
//
//  Tests for MarkdownTag model and MarkdownTagProvider protocol.
//

import Testing
@testable import MarkdownUI

// MARK: - Mock Provider

/// A simple in-memory tag provider for testing.
struct MockTagProvider: MarkdownTagProvider {
    let tags: [MarkdownTag]

    func availableTags(matching prefix: String) async -> [MarkdownTag] {
        if prefix.isEmpty { return tags }
        return tags.filter { $0.name.hasPrefix(prefix) }
    }

    func allTags() async -> [MarkdownTag] {
        tags
    }
}

// MARK: - Tests

@Suite("MarkdownTag & MarkdownTagProvider Tests")
struct MarkdownTagProviderTests {

    // MARK: - MarkdownTag Model

    @Test("Tag id equals name")
    func tagIdEqualsName() {
        let tag = MarkdownTag(name: "must-do")
        #expect(tag.id == "must-do")
    }

    @Test("Tag with all properties")
    func tagWithAllProperties() {
        let tag = MarkdownTag(name: "zoo", color: "#FF3B30", usageCount: 12)
        #expect(tag.name == "zoo")
        #expect(tag.color == "#FF3B30")
        #expect(tag.usageCount == 12)
    }

    @Test("Tag defaults: color nil, usageCount 0")
    func tagDefaults() {
        let tag = MarkdownTag(name: "test")
        #expect(tag.color == nil)
        #expect(tag.usageCount == 0)
    }

    @Test("Tags with same name are equal")
    func tagEquality() {
        let tag1 = MarkdownTag(name: "tag", usageCount: 1)
        let tag2 = MarkdownTag(name: "tag", usageCount: 1)
        #expect(tag1 == tag2)
    }

    @Test("Tags are Hashable")
    func tagHashable() {
        let tag1 = MarkdownTag(name: "a")
        let tag2 = MarkdownTag(name: "b")
        let set: Set<MarkdownTag> = [tag1, tag2]
        #expect(set.count == 2)
    }

    // MARK: - MarkdownTagProvider

    @Test("Provider returns all tags")
    func providerAllTags() async {
        let provider = MockTagProvider(tags: [
            MarkdownTag(name: "must-do"),
            MarkdownTag(name: "zoo"),
        ])
        let result = await provider.allTags()
        #expect(result.count == 2)
    }

    @Test("Provider filters by prefix")
    func providerFiltersByPrefix() async {
        let provider = MockTagProvider(tags: [
            MarkdownTag(name: "must-do"),
            MarkdownTag(name: "museum"),
            MarkdownTag(name: "zoo"),
        ])
        let result = await provider.availableTags(matching: "mus")
        #expect(result.count == 2)
        #expect(result.allSatisfy { $0.name.hasPrefix("mus") })
    }

    @Test("Provider returns all on empty prefix")
    func providerEmptyPrefix() async {
        let provider = MockTagProvider(tags: [
            MarkdownTag(name: "a"),
            MarkdownTag(name: "b"),
        ])
        let result = await provider.availableTags(matching: "")
        #expect(result.count == 2)
    }
}
