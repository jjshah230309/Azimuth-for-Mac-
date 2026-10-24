// Draws the app icon (a compass needle on a dark tile) into an .iconset folder.
// Usage: swift make-icon.swift <output.iconset>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <output.iconset>\n".utf8))
    exit(2)
}
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

func render(pixels: Int) -> CGImage {
    let size = CGFloat(pixels)
    let context = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

    let tile = CGRect(x: size * 0.06, y: size * 0.06, width: size * 0.88, height: size * 0.88)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: size * 0.2, cornerHeight: size * 0.2, transform: nil)
    context.addPath(tilePath)
    context.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [CGColor(red: 0.07, green: 0.12, blue: 0.24, alpha: 1),
                 CGColor(red: 0.16, green: 0.30, blue: 0.52, alpha: 1)] as CFArray,
        locations: [0, 1])!
    context.drawLinearGradient(
        gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])

    let center = CGPoint(x: size / 2, y: size / 2)
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.35))
    context.setLineWidth(size * 0.012)
    context.strokeEllipse(in: CGRect(x: center.x - size * 0.3, y: center.y - size * 0.3,
                                     width: size * 0.6, height: size * 0.6))

    func needle(tip: CGPoint, color: CGColor) {
        let side = size * 0.07
        let path = CGMutablePath()
        path.move(to: tip)
        path.addLine(to: CGPoint(x: center.x - side, y: center.y))
        path.addLine(to: CGPoint(x: center.x + side, y: center.y))
        path.closeSubpath()
        context.setFillColor(color)
        context.addPath(path)
        context.fillPath()
    }
    // Needle tilted to a bearing, like an azimuth angle.
    let angle = CGFloat.pi / 5
    let length = size * 0.3
    context.saveGState()
    context.translateBy(x: center.x, y: center.y)
    context.rotate(by: -angle)
    context.translateBy(x: -center.x, y: -center.y)
    needle(tip: CGPoint(x: center.x, y: center.y + length), color: CGColor(red: 1, green: 0.42, blue: 0.3, alpha: 1))
    needle(tip: CGPoint(x: center.x, y: center.y - length), color: CGColor(red: 0.92, green: 0.95, blue: 1, alpha: 1))
    context.restoreGState()

    context.setFillColor(CGColor(red: 0.07, green: 0.12, blue: 0.24, alpha: 1))
    context.fillEllipse(in: CGRect(x: center.x - size * 0.035, y: center.y - size * 0.035,
                                   width: size * 0.07, height: size * 0.07))
    return context.makeImage()!
}

func write(_ image: CGImage, to url: URL) {
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        FileHandle.standardError.write(Data("could not write \(url.path)\n".utf8))
        exit(1)
    }
}

// iconutil expects these exact names.
let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for entry in sizes {
    write(render(pixels: entry.pixels), to: outputDirectory.appendingPathComponent("\(entry.name).png"))
}
