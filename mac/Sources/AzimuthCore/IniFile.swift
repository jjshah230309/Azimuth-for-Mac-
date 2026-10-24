import Foundation

/// Minimal editor for `azimuth.ini`. Azimuth owns the file, so every line other than the one
/// being changed is left exactly as it was.
public enum IniFile {
    public static func value(for key: String, section: String, in text: String) -> String? {
        var current = ""
        for line in lines(of: text) {
            if let name = sectionName(line) {
                current = name
            } else if current.caseInsensitiveCompare(section) == .orderedSame,
                      let (k, v) = keyValue(line), k.caseInsensitiveCompare(key) == .orderedSame {
                return v
            }
        }
        return nil
    }

    /// Returns `text` with `key` in `[section]` set to `value`, adding the key or section if needed.
    public static func setting(_ key: String, to value: String, section: String, in text: String) -> String {
        let newline = text.contains("\r\n") ? "\r\n" : "\n"
        var result = lines(of: text)
        let entry = "\(key)=\(value)"

        var current = ""
        var lastLineOfSection: Int?
        for (index, line) in result.enumerated() {
            if let name = sectionName(line) {
                current = name
                if name.caseInsensitiveCompare(section) == .orderedSame { lastLineOfSection = index }
            } else if current.caseInsensitiveCompare(section) == .orderedSame {
                if let (k, _) = keyValue(line), k.caseInsensitiveCompare(key) == .orderedSame {
                    result[index] = entry
                    return join(result, newline)
                }
                if !line.trimmingCharacters(in: .whitespaces).isEmpty { lastLineOfSection = index }
            }
        }

        if let last = lastLineOfSection {
            result.insert(entry, at: last + 1)
        } else {
            if let tail = result.last, !tail.isEmpty { result.append("") }
            result.append("[\(section)]")
            result.append(entry)
        }
        return join(result, newline)
    }

    /// Edits the file in place, creating it when absent.
    public static func set(_ key: String, to value: String, section: String, in file: URL) throws {
        let existing = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
        let updated = setting(key, to: value, section: section, in: existing)
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try updated.write(to: file, atomically: true, encoding: .utf8)
    }

    // MARK: Parsing

    private static func lines(of text: String) -> [String] {
        if text.isEmpty { return [] }
        var parts = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        // A trailing newline produces an empty final element; join() puts it back.
        if parts.last == "" { parts.removeLast() }
        return parts
    }

    private static func join(_ lines: [String], _ newline: String) -> String {
        lines.joined(separator: newline) + newline
    }

    private static func sectionName(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("["), trimmed.hasSuffix("]") else { return nil }
        return String(trimmed.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
    }

    private static func keyValue(_ line: String) -> (String, String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix(";"), !trimmed.hasPrefix("#"),
              let equals = trimmed.firstIndex(of: "=")
        else { return nil }
        let key = trimmed[..<equals].trimmingCharacters(in: .whitespaces)
        let value = trimmed[trimmed.index(after: equals)...].trimmingCharacters(in: .whitespaces)
        return (key, value)
    }
}
