import Foundation

/// Pure, rule-based classification of a browser item into a `FileCategory`,
/// extracted from the view so it is unit-testable. Order matters: noise
/// (dependency/build dirs, temp artifacts) is checked before the generic
/// folder/extension rules so `node_modules` doesn't just read as "folder".
enum FileCategoryClassifier {
    /// Directory names that are almost always agent/build noise rather than
    /// content the developer authored.
    static let noiseDirectoryNames: Set<String> = [
        "node_modules", ".build", "build", "dist", ".next", ".turbo", "target",
        "__pycache__", ".venv", "venv", ".gradle", "DerivedData", ".cache",
        ".pytest_cache", ".mypy_cache", "Pods", ".terraform",
    ]

    static let documentExtensions: Set<String> = ["md", "markdown", "txt", "rtf", "pdf", "doc", "docx", "pages"]
    static let codeExtensions: Set<String> = [
        "swift", "py", "js", "ts", "jsx", "tsx", "go", "rs", "java", "kt", "c", "h", "cpp", "hpp", "m", "mm",
        "rb", "php", "sh", "bash", "zsh", "lua", "sql", "css", "scss", "html",
    ]
    static let dataExtensions: Set<String> = [
        "json", "yaml", "yml", "toml", "xml", "csv", "tsv", "plist", "env", "ini", "lock",
    ]
    static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "svg", "webp", "heic", "tiff", "bmp", "icns", "ico",
    ]
    static let archiveExtensions: Set<String> = ["zip", "tar", "gz", "tgz", "bz2", "xz", "7z", "rar", "dmg"]
    static let logExtensions: Set<String> = ["log", "out", "err"]

    static func category(of item: BrowserFileItem) -> FileCategory {
        let name = item.name
        let ext = (name as NSString).pathExtension.lowercased()

        if item.isDirectory {
            return noiseDirectoryNames.contains(name) ? .noise : .folder
        }

        // Temp / backup artifacts by name pattern.
        if name.hasSuffix("~") || name.hasSuffix(".tmp") || name.hasSuffix(".swp") || name == ".DS_Store" {
            return .noise
        }

        if logExtensions.contains(ext) { return .log }
        if documentExtensions.contains(ext) { return .document }
        if codeExtensions.contains(ext) { return .code }
        if dataExtensions.contains(ext) { return .data }
        if imageExtensions.contains(ext) { return .image }
        if archiveExtensions.contains(ext) { return .archive }
        return .other
    }
}
