import Foundation

/// Just enough PE parsing to tell a real 64-bit Windows DLL from an error page or a truncated download.
public enum PEFile {
    public static func isX64DLL(at url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe), data.count > 0x40 else {
            return false
        }
        func u16(_ offset: Int) -> Int? {
            guard offset >= 0, offset + 2 <= data.count else { return nil }
            return Int(data[offset]) | Int(data[offset + 1]) << 8
        }
        func u32(_ offset: Int) -> Int? {
            guard let low = u16(offset), let high = u16(offset + 2) else { return nil }
            return low | high << 16
        }

        guard u16(0) == 0x5A4D,                      // "MZ"
              let peOffset = u32(0x3C),
              u32(peOffset) == 0x0000_4550,          // "PE\0\0"
              let machine = u16(peOffset + 4),
              let characteristics = u16(peOffset + 22)
        else { return false }

        return machine == 0x8664 && characteristics & 0x2000 != 0   // x86-64, IMAGE_FILE_DLL
    }
}
