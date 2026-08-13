//
//  ContentProvenanceTests.swift
//  AssistanceKitTests
//
//  Tests for ContentProvenance model and MarkdownProvenanceProvider protocol.
//

import Testing
import Foundation
@testable import MarkdownUI

// MARK: - ContentProvenance Tests

@Suite("ContentProvenance Tests")
struct ContentProvenanceTests {

    // MARK: Initialization

    @Test("Default initializer creates unaccepted provenance")
    func defaultInit() {
        let provenance = ContentProvenance()
        #expect(provenance.sourceURL == nil)
        #expect(provenance.sourceName == nil)
        #expect(provenance.isAccepted == false)
    }

    @Test("Full initializer stores all properties")
    func fullInit() {
        let url = URL(string: "https://example.com/article")!
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let provenance = ContentProvenance(
            sourceURL: url,
            sourceName: "Example Blog",
            importDate: date,
            isAccepted: true
        )
        #expect(provenance.sourceURL == url)
        #expect(provenance.sourceName == "Example Blog")
        #expect(provenance.importDate == date)
        #expect(provenance.isAccepted == true)
    }

    // MARK: Display Name

    @Test("displayName returns sourceName when available")
    func displayNameFromSourceName() {
        let provenance = ContentProvenance(sourceName: "Wikipedia")
        #expect(provenance.displayName == "Wikipedia")
    }

    @Test("displayName falls back to URL host when no sourceName")
    func displayNameFromURLHost() {
        let url = URL(string: "https://en.wikipedia.org/wiki/Swift")!
        let provenance = ContentProvenance(sourceURL: url)
        #expect(provenance.displayName == "en.wikipedia.org")
    }

    @Test("displayName returns nil when neither sourceName nor URL available")
    func displayNameNil() {
        let provenance = ContentProvenance()
        #expect(provenance.displayName == nil)
    }

    @Test("displayName prefers sourceName over URL host")
    func displayNamePrefersSourceName() {
        let url = URL(string: "https://example.com")!
        let provenance = ContentProvenance(sourceURL: url, sourceName: "My Blog")
        #expect(provenance.displayName == "My Blog")
    }

    // MARK: Codable Roundtrip

    @Test("Codable roundtrip preserves all properties")
    func codableRoundtrip() throws {
        let url = URL(string: "https://example.com/article")!
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let original = ContentProvenance(
            sourceURL: url,
            sourceName: "Example Blog",
            importDate: date,
            isAccepted: false
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ContentProvenance.self, from: data)

        #expect(decoded == original)
    }

    @Test("Codable roundtrip with nil optional fields")
    func codableRoundtripWithNils() throws {
        let original = ContentProvenance(
            importDate: Date(timeIntervalSince1970: 1_700_000_000),
            isAccepted: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ContentProvenance.self, from: data)

        #expect(decoded.sourceURL == nil)
        #expect(decoded.sourceName == nil)
        #expect(decoded.isAccepted == true)
    }

    // MARK: Equatable

    @Test("Equatable compares all properties")
    func equatable() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let a = ContentProvenance(sourceName: "A", importDate: date)
        let b = ContentProvenance(sourceName: "A", importDate: date)
        let c = ContentProvenance(sourceName: "C", importDate: date)
        #expect(a == b)
        #expect(a != c)
    }

    @Test("Mutating isAccepted changes equality")
    func acceptedChangesEquality() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        var a = ContentProvenance(sourceName: "A", importDate: date, isAccepted: false)
        let b = ContentProvenance(sourceName: "A", importDate: date, isAccepted: false)
        #expect(a == b)
        a.isAccepted = true
        #expect(a != b)
    }
}

// MARK: - MarkdownProvenanceProvider Tests

/// A mock provenance provider for testing the protocol.
private struct MockProvenanceProvider: MarkdownProvenanceProvider {
    var provenanceMap: [Int: ContentProvenance] = [:]
    var acceptedBlocks: Set<Int> = []

    func provenance(forBlockAt index: Int) async -> ContentProvenance? {
        provenanceMap[index]
    }

    func acceptContent(atBlockIndex index: Int) async {
        // In a real implementation, this would mutate persistent storage.
        // For tests, we just verify the method is callable.
    }
}

@Suite("MarkdownProvenanceProvider Tests")
struct MarkdownProvenanceProviderTests {

    @Test("Provider returns provenance for mapped block")
    func providerReturnsMappedProvenance() async {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let provenance = ContentProvenance(
            sourceURL: URL(string: "https://example.com"),
            sourceName: "Example",
            importDate: date
        )
        let provider = MockProvenanceProvider(provenanceMap: [0: provenance])
        let result = await provider.provenance(forBlockAt: 0)
        #expect(result == provenance)
    }

    @Test("Provider returns nil for unmapped block")
    func providerReturnsNilForUnmapped() async {
        let provider = MockProvenanceProvider()
        let result = await provider.provenance(forBlockAt: 5)
        #expect(result == nil)
    }

    @Test("Accept content is callable")
    func acceptContentCallable() async {
        let provider = MockProvenanceProvider()
        // Verify the method can be called without error.
        await provider.acceptContent(atBlockIndex: 0)
    }
}
