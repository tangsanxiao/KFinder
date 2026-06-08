import CoreServices
import Foundation

/// Filesystem watching via FSEvents, exposed as an `AsyncStream` so a pane can
/// `for await` change notifications and auto-refresh. Reports changes anywhere
/// under the directory (files added/removed/renamed or their contents edited),
/// which also covers expanded subfolders. Events are coalesced (0.4s latency)
/// and only the newest pending tick is buffered, so bursts collapse into one
/// reload. The stream tears the FSEvents stream down when the consuming task is
/// cancelled (e.g. the pane navigates elsewhere or disappears).
enum DirectoryWatcher {
    static func changes(of url: URL) -> AsyncStream<Void> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            final class Sink {
                let yield: () -> Void
                init(_ yield: @escaping () -> Void) { self.yield = yield }
            }

            let sink = Sink { continuation.yield(()) }
            var context = FSEventStreamContext(
                version: 0,
                info: Unmanaged.passRetained(sink).toOpaque(),
                retain: nil,
                release: { info in
                    if let info { Unmanaged<Sink>.fromOpaque(info).release() }
                },
                copyDescription: nil
            )

            let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
                guard let info else { return }
                Unmanaged<Sink>.fromOpaque(info).takeUnretainedValue().yield()
            }

            let flags = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
            guard
                let stream = FSEventStreamCreate(
                    kCFAllocatorDefault,
                    callback,
                    &context,
                    [url.path] as CFArray,
                    FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                    0.4,
                    flags
                )
            else {
                continuation.finish()
                return
            }

            let queue = DispatchQueue(label: "com.xfinder.fsevents")
            FSEventStreamSetDispatchQueue(stream, queue)
            FSEventStreamStart(stream)

            // FSEventStreamRef is a non-Sendable OpaquePointer; it is only ever
            // touched on `queue`, so capturing it in the teardown is safe.
            nonisolated(unsafe) let capturedStream = stream
            continuation.onTermination = { _ in
                FSEventStreamStop(capturedStream)
                FSEventStreamInvalidate(capturedStream)
                FSEventStreamRelease(capturedStream)
            }
        }
    }
}
