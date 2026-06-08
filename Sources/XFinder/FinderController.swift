import AppKit
import Foundation

final class FinderController {
    func currentFinderWindowDirectories() throws -> [URL] {
        let script = """
            tell application "Finder"
                set output to ""
                repeat with finderWindow in Finder windows
                    try
                        set output to output & POSIX path of (target of finderWindow as alias) & linefeed
                    end try
                end repeat
                return output
            end tell
            """
        let descriptor = try execute(script)
        let output = descriptor.stringValue ?? ""
        return
            output
            .split(separator: "\n")
            .map(String.init)
            .map { URL(fileURLWithPath: $0) }
    }

    @discardableResult
    private func execute(_ source: String) throws -> NSAppleEventDescriptor {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            throw WorkspaceStoreError.appleScript("Could not create AppleScript.")
        }

        let result = script.executeAndReturnError(&error)
        if let error {
            throw WorkspaceStoreError.appleScript(error.description)
        }
        return result
    }
}
