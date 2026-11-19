import XCTest
@testable import AzimuthCore

final class IniFileTests: XCTestCase {
    func testReplacesExistingValueAndKeepsOtherLines() {
        let text = "; comment\n[launcher]\nplayer_name=Ada\ngame_folder=D:\\Old\n\n[graphics]\nresolution=4k\n"
        let result = IniFile.setting("game_folder", to: "G:\\", section: "launcher", in: text)
        XCTAssertEqual(
            result,
            "; comment\n[launcher]\nplayer_name=Ada\ngame_folder=G:\\\n\n[graphics]\nresolution=4k\n")
    }

    func testAddsKeyToExistingSectionBeforeNextSection() {
        let text = "[launcher]\nplayer_name=Ada\n\n[graphics]\nresolution=4k\n"
        let result = IniFile.setting("game_folder", to: "G:\\", section: "launcher", in: text)
        XCTAssertEqual(result, "[launcher]\nplayer_name=Ada\ngame_folder=G:\\\n\n[graphics]\nresolution=4k\n")
    }

    func testAddsSectionWhenMissing() {
        let result = IniFile.setting("game_folder", to: "G:\\", section: "launcher", in: "[graphics]\nresolution=4k\n")
        XCTAssertEqual(result, "[graphics]\nresolution=4k\n\n[launcher]\ngame_folder=G:\\\n")
    }

    func testCreatesContentForEmptyFile() {
        XCTAssertEqual(
            IniFile.setting("game_folder", to: "G:\\", section: "launcher", in: ""),
            "[launcher]\ngame_folder=G:\\\n")
    }

    func testKeepsWindowsLineEndings() {
        let text = "[launcher]\r\ngame_folder=D:\\Old\r\n"
        let result = IniFile.setting("game_folder", to: "G:\\", section: "launcher", in: text)
        XCTAssertEqual(result, "[launcher]\r\ngame_folder=G:\\\r\n")
    }

    func testKeyOfAnotherSectionIsNotTouched() {
        let text = "[graphics]\ngame_folder=keep\n[launcher]\n"
        let result = IniFile.setting("game_folder", to: "G:\\", section: "launcher", in: text)
        XCTAssertEqual(result, "[graphics]\ngame_folder=keep\n[launcher]\ngame_folder=G:\\\n")
    }

    func testReadsValueCaseInsensitively() {
        let text = "[Launcher]\nGame_Folder = G:\\\n"
        XCTAssertEqual(IniFile.value(for: "game_folder", section: "launcher", in: text), "G:\\")
        XCTAssertNil(IniFile.value(for: "missing", section: "launcher", in: text))
    }

    func testWritesFileInNewDirectory() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("nested/azimuth.ini")
        try IniFile.set("game_folder", to: "G:\\", section: "launcher", in: file)
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "[launcher]\ngame_folder=G:\\\n")
    }
}
