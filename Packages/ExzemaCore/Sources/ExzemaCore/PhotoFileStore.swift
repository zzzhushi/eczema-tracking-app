import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum PhotoFileError: Error, Equatable {
    case unreadableImage
    case encodingFailed
    /// A file name that is empty or names anything outside the photo directory.
    case invalidFileName
}

/// The photo images, one JPEG file each, in a directory dedicated to them.
///
/// Images are downscaled, stripped of all camera metadata including location, protected until the first unlock
/// after a restart, and excluded from device and cloud backups.
public final class PhotoFileStore: Sendable {
    /// The longest side, in pixels, of a stored photo.
    public static let maxLongEdge = 1600

    private static let jpegQuality = 0.85

    private let directory: URL

    /// Open the store in `directory`, creating it if needed. The directory must be dedicated to photos.
    public init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.excludeFromBackup(directory)
    }

    /// Downscale `imageData` to `maxLongEdge`, apply its orientation, drop its metadata, store it, and return the
    /// new file's name. Throws `PhotoFileError.unreadableImage` for data that is not an image, storing nothing.
    public func save(imageData: Data) throws -> String {
        let encoded = try Self.encode(imageData, maxPixel: Self.maxLongEdge)
        let name = "\(UUID().uuidString).jpg"
        let url = try fileURL(for: name)
        try write(encoded, to: url)
        return name
    }

    /// Return the stored image, which is at most `maxLongEdge` on its long side.
    public func imageData(fileName: String) throws -> Data {
        try Data(contentsOf: fileURL(for: fileName))
    }

    /// Return a JPEG of the stored image at most `maxPixel` on its long side.
    public func thumbnailData(fileName: String, maxPixel: Int) throws -> Data {
        try Self.encode(imageData(fileName: fileName), maxPixel: maxPixel)
    }

    /// Remove an image file; a file that is already gone is not an error.
    public func delete(fileName: String) throws {
        let url = try fileURL(for: fileName)
        do {
            try FileManager.default.removeItem(at: url)
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            return
        }
    }

    /// Return the names of the stored image files.
    public func fileNames() throws -> Set<String> {
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        return Set(names.filter { $0.hasSuffix(".jpg") })
    }

    /// Return where an image file is, refusing any name that could point outside the photo directory.
    public func fileURL(for fileName: String) throws -> URL {
        guard !fileName.isEmpty, !fileName.contains("/"), !fileName.hasPrefix(".") else {
            throw PhotoFileError.invalidFileName
        }
        return directory.appendingPathComponent(fileName)
    }

    private func write(_ data: Data, to url: URL) throws {
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: url, options: .atomic)
        #endif
        try Self.excludeFromBackup(url)
    }

    private static func encode(_ imageData: Data, maxPixel: Int) throws -> Data {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { throw PhotoFileError.unreadableImage }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw PhotoFileError.unreadableImage
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw PhotoFileError.encodingFailed
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: jpegQuality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw PhotoFileError.encodingFailed }
        return output as Data
    }

    private static func excludeFromBackup(_ url: URL) throws {
        var url = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }
}
