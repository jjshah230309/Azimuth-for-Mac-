import Foundation

/// Azimuth wants "the folder holding `Mount`" (its own wording for the Xbox game's package folder).
public enum GameFolder {
    public enum Check: Equatable {
        case valid
        /// The chosen folder has no `Mount`, but this subfolder does.
        case useSubfolder(URL)
        case missingMount
        case notAFolder
    }

    public static func check(_ folder: URL) -> Check {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: folder.path, isDirectory: &isDir), isDir.boolValue else {
            return .notAFolder
        }
        if fm.fileExists(atPath: folder.appendingPathComponent("Mount").path) { return .valid }

        let children = (try? fm.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        for child in children.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            var childIsDir: ObjCBool = false
            if fm.fileExists(atPath: child.path, isDirectory: &childIsDir), childIsDir.boolValue,
               fm.fileExists(atPath: child.appendingPathComponent("Mount").path) {
                return .useSubfolder(child)
            }
        }
        return .missingMount
    }
}
