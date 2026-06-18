import Foundation
import Testing

@testable import XFinder

@Test func parsesFrontmatterNameDescriptionQuotes() {
    let content = """
        ---
        name: "volcengine-cli"
        description: 'Manage Volcengine resources.'
        version: 1.2.0
        ---

        # Body
        name: not-frontmatter
        """
    let meta = SkillCatalog.metadata(from: content)
    #expect(meta.name == "volcengine-cli")
    #expect(meta.description == "Manage Volcengine resources.")
    #expect(meta.version == "1.2.0")
    // Keys after the closing --- are body, not frontmatter.
}

@Test func missingFrontmatterYieldsEmptyMetadata() {
    #expect(SkillCatalog.metadata(from: "# Just a heading\n") == SkillCatalog.Metadata())
}

@Test func aggregateGroupsByNameAcrossAgentsAndSorts() {
    let raws = [
        raw(.claudeCode, "/a/zeta", "h1", name: "zeta"),
        raw(.claudeCode, "/a/alpha", "h2", name: "alpha"),
        raw(.traeCN, "/b/alpha", "h2", name: "alpha"),  // same content as claude alpha
    ]
    let entries = SkillCatalog.aggregate(raws)

    #expect(entries.map(\.name) == ["alpha", "zeta"])  // sorted
    let alpha = entries.first { $0.name == "alpha" }!
    #expect(alpha.agents == [.claudeCode, .traeCN])
    #expect(alpha.hasDrift == false)  // identical hashes
}

@Test func aggregateDetectsDriftAndFallsBackToFolderName() {
    let raws = [
        raw(.claudeCode, "/a/tool", "hA", name: nil),  // no frontmatter name → folder "tool"
        raw(.traeCN, "/b/tool", "hB", name: nil),  // different content
    ]
    let entries = SkillCatalog.aggregate(raws)
    #expect(entries.count == 1)
    #expect(entries[0].name == "tool")
    #expect(entries[0].hasDrift)  // hA != hB
}

@Test func stableHashIsDeterministicAndDistinguishes() {
    #expect(SkillCatalog.stableHash("abc") == SkillCatalog.stableHash("abc"))
    #expect(SkillCatalog.stableHash("abc") != SkillCatalog.stableHash("abd"))
}

private func raw(_ agent: SkillAgent, _ path: String, _ hash: String, name: String?) -> SkillCatalog.RawSkill {
    SkillCatalog.RawSkill(
        agent: agent,
        url: URL(fileURLWithPath: path),
        isReadOnly: false,
        contentHash: hash,
        metadata: SkillCatalog.Metadata(name: name, description: "d", version: nil, license: nil)
    )
}
