// Re-encodes photos for the local fixtures folder: upright, long edge at most 1600 px,
// JPEG, and no metadata (no EXIF, GPS, dates, or device information).
// Usage: swift scripts/prepare_fixture_photos.swift <outDir> <input>=<name> [<input>=<name> ...]
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = Array(CommandLine.arguments.dropFirst())
guard args.count >= 2 else { fatalError("usage: <outDir> <input>=<name> ...") }
let outDir = URL(fileURLWithPath: args[0], isDirectory: true)
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

for pair in args.dropFirst() {
    let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
    guard parts.count == 2, let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: parts[0]) as CFURL, nil) else {
        fatalError("cannot read \(pair)")
    }
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: 1600,
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { fatalError("cannot decode \(parts[0])") }
    let outURL = outDir.appendingPathComponent(parts[1] + ".jpg")
    guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { fatalError("cannot write \(outURL.path)") }
    CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { fatalError("cannot finalize \(outURL.path)") }
    print("\(parts[1]).jpg  \(image.width)x\(image.height)")
}
