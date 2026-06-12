import UIKit

/// Flare photos live in the app's own sandbox (Documents/FlarePhotos), never
/// in the shared photo library and never on a server. Files are written with
/// complete file protection so they are encrypted at rest while the device
/// is locked.
enum PhotoStore {
    static var directory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FlarePhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func save(_ data: Data) -> String? {
        guard let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.85) else { return nil }
        let filename = UUID().uuidString + ".jpg"
        do {
            try jpeg.write(to: directory.appendingPathComponent(filename), options: .completeFileProtection)
            return filename
        } catch {
            return nil
        }
    }

    static func image(named filename: String) -> UIImage? {
        UIImage(contentsOfFile: directory.appendingPathComponent(filename).path)
    }

    static func delete(_ filename: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(filename))
    }
}
