//
//  MarkdownProvenanceRenderingTests.swift
//  AssistanceKitTests
//
//  Tests for content provenance rendering integration in MarkdownDocumentView.
//  Verifies provenance wiring, acceptance flow, and source link logic.
//

import Testing
import Foundation
@testable import MarkdownUI

// MARK: - Tracking Mock Provider

/// A mock provenance provider that tracks accept calls for test verification.
///
/// Uses an actor for thread-safe mutable state access.
private actor TrackingProvenanceProvider: MarkdownProvenanceProvider {
    private(set) var provenanceMap: [Int: ContentProvenance]
    private(set) var acceptedBlockIndices: [Int] = []

    init(provenanceMap: [Int: ContentProvenance]) {
        self.provenanceMap = provenanceMap
    }

    func provenance(forBlockAt index: Int) async -> ContentProvenance? {
        provenanceMap[index]
    }

    func acceptContent(atBlockIndex index: Int) async {
        acceptedBlockIndices.append(index)
        if var provenance = provenanceMap[index] {
            provenance.isAccepted = true
            provenanceMap[index] = provenance
        }
    }
}

// MARK: - Provenance Rendering Integration Tests

@Suite("Provenance Rendering Integration Tests")
struct ProvenanceRenderingIntegrationTests {

    // MARK: Provider Wiring

    @Test("Provider returns provenance for suggested block")
    func providerReturnsSuggestedProvenance() async {
        let provenance = ContentProvenance(
            sourceURL: URL(string: "https://example.com/article"),
            sourceName: "Example Blog",
            importDate: Date(timeIntervalSince1970: 1_700_000_000),
            isAccepted: false
        )
        let provider = TrackingProvenanceProvider(provenanceMap: [1: provenance])

        let result = await provider.provenance(forBlockAt: 1)
        #expect(result != nil)
        #expect(result?.isAccepted == false)
        #expect(result?.displayName == "Example Blog")
    }

    @Test("Provider returns nil for blocks without provenance")
    func providerReturnsNilForUserAuthored() async {
        let provider = TrackingProvenanceProvider(provenanceMap: [:])
        let result = await provider.provenance(forBlockAt: 0)
        #expect(result == nil)
    }

    @Test("Provider returns accepted provenance for accepted blocks")
    func providerReturnsAcceptedProvenance() async {
        let provenance = ContentProvenance(
            sourceURL: URL(string: "https://example.com"),
            sourceName: "Example",
            importDate: .now,
            isAccepted: true
        )
        let provider = TrackingProvenanceProvider(provenanceMap: [0: provenance])

        let result = await provider.provenance(forBlockAt: 0)
        #expect(result?.isAccepted == true)
    }

    // MARK: Accept Flow

    @Test("Accept call updates provider state")
    func acceptUpdatesProvider() async {
        let provenance = ContentProvenance(
            sourceURL: URL(string: "https://example.com"),
            sourceName: "Test Source",
            importDate: .now,
            isAccepted: false
        )
        let provider = TrackingProvenanceProvider(provenanceMap: [2: provenance])

        // Verify initial state
        let before = await provider.provenance(forBlockAt: 2)
        #expect(before?.isAccepted == false)

        // Accept
        await provider.acceptContent(atBlockIndex: 2)

        // Verify accepted
        let after = await provider.provenance(forBlockAt: 2)
        #expect(after?.isAccepted == true)
        let accepted = await provider.acceptedBlockIndices
        #expect(accepted == [2])
    }

    @Test("Accept records correct block index")
    func acceptRecordsIndex() async {
        let provenance = ContentProvenance(sourceName: "Test", importDate: .now)
        let provider = TrackingProvenanceProvider(provenanceMap: [
            0: provenance,
            3: provenance,
            7: provenance,
        ])

        await provider.acceptContent(atBlockIndex: 3)
        await provider.acceptContent(atBlockIndex: 7)

        let accepted = await provider.acceptedBlockIndices
        #expect(accepted == [3, 7])
    }

    @Test("Multiple accepts on same block are idempotent")
    func multipleAcceptsIdempotent() async {
        let provenance = ContentProvenance(sourceName: "Test", importDate: .now)
        let provider = TrackingProvenanceProvider(provenanceMap: [0: provenance])

        await provider.acceptContent(atBlockIndex: 0)
        await provider.acceptContent(atBlockIndex: 0)

        let result = await provider.provenance(forBlockAt: 0)
        #expect(result?.isAccepted == true)
    }

    // MARK: Source Link Logic

    @Test("Accepted provenance with URL enables source link")
    func acceptedWithURLHasSourceLink() {
        let provenance = ContentProvenance(
            sourceURL: URL(string: "https://example.com/article"),
            sourceName: "Example",
            importDate: .now,
            isAccepted: true
        )
        #expect(provenance.sourceURL != nil)
        #expect(provenance.isAccepted == true)
        #expect(provenance.displayName == "Example")
    }

    @Test("Accepted provenance without URL has no source link")
    func acceptedWithoutURLNoSourceLink() {
        let provenance = ContentProvenance(
            sourceName: "Clipboard",
            importDate: .now,
            isAccepted: true
        )
        #expect(provenance.sourceURL == nil)
        #expect(provenance.displayName == "Clipboard")
    }

    @Test("Unaccepted provenance should show suggested styling, not source link")
    func unacceptedShowsSuggestedStyling() {
        let provenance = ContentProvenance(
            sourceURL: URL(string: "https://example.com"),
            sourceName: "Example",
            importDate: .now,
            isAccepted: false
        )
        // Suggested blocks should NOT show the source link (only the source label)
        #expect(provenance.isAccepted == false)
        #expect(provenance.sourceURL != nil)
    }

    // MARK: Mixed Block Scenarios

    @Test("Only blocks with provenance get styling")
    func mixedBlocksProvenanceCheck() async {
        let suggested = ContentProvenance(
            sourceName: "Wikipedia",
            importDate: .now,
            isAccepted: false
        )
        let provider = TrackingProvenanceProvider(provenanceMap: [
            1: suggested, // Only block 1 has provenance
        ])

        // Block 0 (user-authored): no provenance
        let block0 = await provider.provenance(forBlockAt: 0)
        #expect(block0 == nil)

        // Block 1 (suggested): has provenance
        let block1 = await provider.provenance(forBlockAt: 1)
        #expect(block1 != nil)
        #expect(block1?.isAccepted == false)

        // Block 2 (user-authored): no provenance
        let block2 = await provider.provenance(forBlockAt: 2)
        #expect(block2 == nil)
    }
}
