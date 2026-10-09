import ExzemaCore
import SwiftUI
import UIKit

/// The system camera sheet, opened on `device`. It hands back the captured image and the camera's metadata: the lens
/// model names the camera actually used, because the sheet lets the user flip between them, and the shutter time
/// is when the photo was taken, not when Use Photo was tapped. The image is not encoded here, so the main thread
/// does no pixel work before the sheet dismisses.
struct CameraPicker: UIViewControllerRepresentable {
    let device: UIImagePickerController.CameraDevice
    let onCapture: (UIImage, CaptureMetadata) -> Void
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
        let onCapture: (UIImage, CaptureMetadata) -> Void
        let onCancel: () -> Void

        init(onCapture: @escaping (UIImage, CaptureMetadata) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard let image = info[.originalImage] as? UIImage else {
                onCancel()
                return
            }
            let exif = (info[.mediaMetadata] as? [String: Any])?["{Exif}"] as? [String: Any]
            onCapture(image, CaptureMetadata(
                lensModel: exif?["LensModel"] as? String,
                dateTimeOriginal: exif?["DateTimeOriginal"] as? String,
                offsetTimeOriginal: exif?["OffsetTimeOriginal"] as? String
            ))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
