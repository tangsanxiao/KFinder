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
                    let folders =
                        directory.isRecursive
                        ? skillFoldersRecursive(in: directory.url, fileManager: fileManager)
                        : directChildren(of: directory.url, fileManager: fileManager)

                    // Dedupe by skill name within an agent (recursive plugin
                    // caches repeat the same skill across session UUID dirs).
                    var seenNames = Set<String>()
                    for child in folders {
                        let skillFile = child.appendingPathComponent("SKILL.md")
                        guard let content = try? String(contentsOf: skillFile, encoding: .utf8) else { continue }
                        let meta = SkillCatalog.metadata(from: content)
                        let name = meta.name ?? child.lastPathComponent
                        guard seenNames.insert(name).inserted else { continue }
                        let isSymlink =
                            (try? child.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink ?? false
                        raws.append(
                            SkillCatalog.RawSkill(
                                agent: agent,
                                url: child,
                                isReadOnly: directory.isReadOnly,
                                contentHash: SkillCatalog.stableHash(content),
                                metadata: meta,
                                isSymlink: isSymlink
                            ))
                    }
                }
            }

            return SkillCatalog.aggregate(raws)
        }.value
    }

    /// Immediate subdirectories (each a potential `<name>/SKILL.md`).
    private static func directChildren(of url: URL, fileManager: FileManager) -> [URL] {
        (try? fileManager.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey])) ?? []
    }

    /// Every folder containing a SKILL.md at any depth — for nested plugin
    /// layouts (e.g. Claude Desktop's session caches).
    private static func skillFoldersRecursive(in url: URL, fileManager: FileManager) -> [URL] {
        guard
            let enumerator = fileManager.enumerator(
                at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        else { return [] }
        var result: [URL] = []
        for case let fileURL as URL in enumerator where fileURL.lastPathComponent == "SKILL.md" {
            result.append(fileURL.deletingLastPathComponent())
        }
        return result
    }
}
