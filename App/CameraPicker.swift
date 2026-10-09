import SwiftUI
import UIKit

/// The system camera sheet, opened on `device`. It hands back JPEG data and the lens model the photo
/// records, which names the camera actually used because the sheet lets the user flip between them.
struct CameraPicker: UIViewControllerRepresentable {
    let device: UIImagePickerController.CameraDevice
    let onCapture: (Data, String?) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.image"]
        if UIImagePickerController.isCameraDeviceAvailable(device) { picker.cameraDevice = device }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (Data, String?) -> Void
        let onCancel: () -> Void

        init(onCapture: @escaping (Data, String?) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.95) else {
                onCancel()
                return
            }
            let exif = (info[.mediaMetadata] as? [String: Any])?["{Exif}"] as? [String: Any]
            onCapture(data, exif?["LensModel"] as? String)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
