import Foundation

/// Scans every agent's skill directories for `<name>/SKILL.md` and aggregates
/// them into one catalog. Runs off the main actor; parsing/grouping is in
/// `SkillCatalog` (pure, tested) — this layer is just filesystem IO.
enum SkillScanner {
    static func scan(agents: [SkillAgent] = SkillAgent.allCases) async -> [SkillEntry] {
        await Task.detached(priority: .userInitiated) { () -> [SkillEntry] in
            let fileManager = FileManager.default
            var raws: [SkillCatalog.RawSkill] = []

            for agent in agents {
                for directory in agent.scanDirectories {
                    guard
                        let children = try? fileManager.contentsOfDirectory(
                            at: directory.url, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                    else { continue }

                    for child in children {
                        let skillFile = child.appendingPathComponent("SKILL.md")
                        guard let content = try? String(contentsOf: skillFile, encoding: .utf8) else { continue }
                        let isSymlink =
                            (try? child.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink ?? false
                        raws.append(
                            SkillCatalog.RawSkill(
                                agent: agent,
                                url: child,
                                isReadOnly: directory.isReadOnly,
                                contentHash: SkillCatalog.stableHash(content),
                                metadata: SkillCatalog.metadata(from: content),
                                isSymlink: isSymlink
                            ))
                    }
                }
            }

            return SkillCatalog.aggregate(raws)
        }.value
    }
}
