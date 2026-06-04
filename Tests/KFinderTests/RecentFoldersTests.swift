import Testing
@testable import KFinder

@Test func addingToEmptyListInsertsPath() {
    #expect(RecentFolders.updated([], adding: "/a") == ["/a"])
}

@Test func newestPathGoesToFront() {
    #expect(RecentFolders.updated(["/a", "/b"], adding: "/c") == ["/c", "/a", "/b"])
}

@Test func existingPathIsDeduplicatedAndPromoted() {
    #expect(RecentFolders.updated(["/a", "/b", "/c"], adding: "/c") == ["/c", "/a", "/b"])
}

@Test func emptyPathIsIgnored() {
    #expect(RecentFolders.updated(["/a"], adding: "") == ["/a"])
    #expect(RecentFolders.updated(["/a"], adding: "   ") == ["/a"])
}

@Test func listIsCappedAtLimitNewestFirst() {
    let seed = (0..<5).map { "/d\($0)" }
    let result = RecentFolders.updated(seed, adding: "/new", limit: 3)
    #expect(result == ["/new", "/d0", "/d1"])
    #expect(result.count == 3)
}

@Test func reAddingFrontPathIsStable() {
    #expect(RecentFolders.updated(["/a", "/b"], adding: "/a") == ["/a", "/b"])
}
