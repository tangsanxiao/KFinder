import Foundation
import Testing

@testable import XFinder

@Test func directoryWatcherFiresWhenContentsChange() async throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("XFinderWatch-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let stream = DirectoryWatcher.changes(of: dir)

    // Make a change shortly after the stream is armed; bufferingNewest(1) keeps
    // the tick even if it lands before we start awaiting.
    let writer = Task.detached {
        try? await Task.sleep(for: .milliseconds(300))
        try? "hello".write(to: dir.appendingPathComponent("new.txt"), atomically: true, encoding: .utf8)
    }

    let received = await firstTick(stream, timeout: .seconds(10))
    writer.cancel()
    #expect(received)
}

/// Returns true if the stream yields at least one element before the timeout.
private func firstTick(_ stream: AsyncStream<Void>, timeout: Duration) async -> Bool {
    await withTaskGroup(of: Bool.self) { group in
        group.addTask {
            for await _ in stream { return true }
            return false
        }
        group.addTask {
            try? await Task.sleep(for: timeout)
            return false
        }
        let result = await group.next() ?? false
        group.cancelAll()
        return result
    }
}
