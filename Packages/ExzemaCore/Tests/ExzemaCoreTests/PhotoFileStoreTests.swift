import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
import ExzemaCore

@Suite("Photo files")
struct PhotoFileStoreTests {
    private let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PhotoFileStoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func openStore() throws -> PhotoFileStore {
        try PhotoFileStore(directory: directory.appendingPathComponent("Photos", isDirectory: true))
    }

    /// A JPEG of a flat colour carrying a GPS position, as a camera would produce.
    private func jpeg(width: Int, height: Int, orientation: Int = 1, withLocation: Bool = true) throws -> Data {
        let space = CGColorSpaceCreateDeviceRGB()
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(red: 0.8, green: 0.4, blue: 0.4, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let output = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil))
        var properties: [CFString: Any] = [kCGImagePropertyOrientation: orientation]
        if withLocation {
            properties[kCGImagePropertyGPSDictionary] = [
                kCGImagePropertyGPSLatitude: 37.7749, kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 122.4194, kCGImagePropertyGPSLongitudeRef: "W",
            ]
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return output as Data
    }

    private func properties(of data: Data) throws -> [CFString: Any] {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        return try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    }

    private func size(of data: Data) throws -> (width: Int, height: Int) {
        let found = try properties(of: data)
        return (found[kCGImagePropertyPixelWidth] as? Int ?? 0, found[kCGImagePropertyPixelHeight] as? Int ?? 0)
    }

    @Test func largePhotoIsDownscaledToTheLongEdgeLimit() throws {
        let store = try openStore()
        let name = try store.save(imageData: jpeg(width: 4032, height: 3024))

        let (width, height) = try size(of: store.imageData(fileName: name))
        #expect(max(width, height) == PhotoFileStore.maxLongEdge)
        #expect(abs(Double(width) / Double(height) - 4032.0 / 3024.0) < 0.01, "the aspect ratio is kept")
    }

    @Test func smallPhotoIsNotEnlarged() throws {
        let store = try openStore()
        let name = try store.save(imageData: jpeg(width: 800, height: 600))

        let (width, height) = try size(of: store.imageData(fileName: name))
        #expect(max(width, height) <= 800)
    }

    @Test func storedPhotoCarriesNoLocation() throws {
        let store = try openStore()
        let source = try jpeg(width: 2000, height: 1500)
        #expect(try properties(of: source)[kCGImagePropertyGPSDictionary] != nil, "the test image starts with a position")

        let name = try store.save(imageData: source)

        #expect(try properties(of: store.imageData(fileName: name))[kCGImagePropertyGPSDictionary] == nil)
    }

    @Test func rotationFromTheCameraIsAppliedToThePixels() throws {
        let store = try openStore()
        let name = try store.save(imageData: jpeg(width: 2000, height: 1000, orientation: 6))

        let (width, height) = try size(of: store.imageData(fileName: name))
        #expect(height > width, "a photo marked as rotated a quarter turn is stored upright")
        let orientation = try properties(of: store.imageData(fileName: name))[kCGImagePropertyOrientation] as? Int
        #expect(orientation == nil || orientation == 1)
    }

    @Test func eachPhotoGetsItsOwnFileName() throws {
        let store = try openStore()
        let data = try jpeg(width: 400, height: 300)

        #expect(try store.save(imageData: data) != store.save(imageData: data))
    }

    @Test func dataThatIsNotAnImageIsRefusedAndStoresNothing() throws {
        let store = try openStore()

        #expect(throws: PhotoFileError.unreadableImage) { try store.save(imageData: Data("not an image".utf8)) }
        #expect(try store.fileNames().isEmpty)
    }

    @Test func thumbnailFitsTheRequestedSize() throws {
        let store = try openStore()
        let name = try store.save(imageData: jpeg(width: 4032, height: 3024))

        let (width, height) = try size(of: store.thumbnailData(fileName: name, maxPixel: 200))
        #expect(max(width, height) == 200)
    }

    @Test func deletingRemovesTheFileAndMissingFilesAreIgnored() throws {
        let store = try openStore()
        let name = try store.save(imageData: jpeg(width: 400, height: 300))

        try store.delete(fileName: name)
        try store.delete(fileName: name)

        #expect(try store.fileNames().isEmpty)
    }

    @Test func listedFileNamesAreTheStoredFiles() throws {
        let store = try openStore()
        let first = try store.save(imageData: jpeg(width: 400, height: 300))
        let second = try store.save(imageData: jpeg(width: 400, height: 300))

        #expect(try store.fileNames() == [first, second])
    }

    @Test func photoDirectoryAndFilesAreExcludedFromBackup() throws {
        let store = try openStore()
        let name = try store.save(imageData: jpeg(width: 400, height: 300))

        let folder = try directory.appendingPathComponent("Photos", isDirectory: true).resourceValues(forKeys: [.isExcludedFromBackupKey])
        let file = try store.fileURL(for: name).resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(folder.isExcludedFromBackup == true)
        #expect(file.isExcludedFromBackup == true)
    }

    @Test func fileNameCannotEscapeThePhotoDirectory() throws {
        let store = try openStore()

        #expect(throws: PhotoFileError.invalidFileName) { try store.imageData(fileName: "../store.sqlite") }
        #expect(throws: PhotoFileError.invalidFileName) { try store.delete(fileName: "a/b.jpg") }
    }

    @Test(arguments: [
        ("iPhone 15 Pro front camera 2.69mm f/1.9", PhotoCamera.front),
        ("iPhone 15 Pro back triple camera 6.765mm f/1.78", PhotoCamera.back),
        ("iPhone 15 Pro back camera 2.22mm f/2.2", PhotoCamera.back),
    ])
    func cameraIsReadFromTheLensModel(lensModel: String, expected: PhotoCamera) {
        #expect(PhotoCamera(lensModel: lensModel) == expected)
    }

    @Test func unrecognisedLensModelGivesNoCamera() {
        #expect(PhotoCamera(lensModel: nil) == nil)
        #expect(PhotoCamera(lensModel: "Some Other Lens") == nil)
    }
}
