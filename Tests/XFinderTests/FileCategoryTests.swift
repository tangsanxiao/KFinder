import Foundation
import Testing

@testable import XFinder

private func item(_ name: String, isDir: Bool = false) -> BrowserFileItem {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("XFinderCat-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let url = root.appendingPathComponent(name)
    if isDir {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    } else {
        try? "x".write(to: url, atomically: true, encoding: .utf8)
    }
    let values = try! url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
    return BrowserFileItem(url: url, resourceValues: values)
}

@Test func classifiesNoiseDirectoriesBeforeFolder() {
    #expect(FileCategoryClassifier.category(of: item("node_modules", isDir: true)) == .noise)
    #expect(FileCategoryClassifier.category(of: item(".build", isDir: true)) == .noise)
    #expect(FileCategoryClassifier.category(of: item("src", isDir: true)) == .folder)
}

@Test func classifiesByExtension() {
    #expect(FileCategoryClassifier.category(of: item("README.md")) == .document)
    #expect(FileCategoryClassifier.category(of: item("main.swift")) == .code)
    #expect(FileCategoryClassifier.category(of: item("config.json")) == .data)
    #expect(FileCategoryClassifier.category(of: item("logo.png")) == .image)
    #expect(FileCategoryClassifier.category(of: item("bundle.zip")) == .archive)
    #expect(FileCategoryClassifier.category(of: item("run.log")) == .log)
    #expect(FileCategoryClassifier.category(of: item("mystery.xyz")) == .other)
}

@Test func classifiesTempArtifactsAsNoise() {
    #expect(FileCategoryClassifier.category(of: item(".DS_Store")) == .noise)
    #expect(FileCategoryClassifier.category(of: item("draft.txt~")) == .noise)
    #expect(FileCategoryClassifier.category(of: item("session.swp")) == .noise)
}
