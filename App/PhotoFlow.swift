import AVFoundation
import ExzemaCore
import Observation
import UIKit

/// A request to take one photo of a slot.
struct CaptureRequest: Identifiable, Equatable {
    let slot: PhotoSlot
    let kind: PhotoKind

    var id: String { "\(slot.id)-\(kind.rawValue)" }
}

/// A camera image handed to the background work that stores it. The image is not changed after capture, and
/// reading a `UIImage` from another thread is safe.
struct CapturedPhoto: @unchecked Sendable {
    let image: UIImage
}

/// The photos of one slot and day that the full-screen viewer pages through, opened on `startID`.
struct PhotoViewerTarget: Identifiable {
    let slotID: String
    let startID: Int64

    var id: Int64 { startID }
}

/// The steps between tapping "Add photo" and the camera: the tips the first time, then camera permission.
@MainActor
@Observable
final class PhotoFlow {
    static let tipsSeenKey = "photoTipsSeen"

    var showingTips = false
    var cameraRequest: CaptureRequest?
    var showingCameraOff = false
    var showingCameraUnavailable = false
    var viewing: PhotoViewerTarget?

    #if DEBUG
    /// Stands in for the camera where there is none, so the flow can be walked through in the simulator.
    @ObservationIgnored var simulatorCapture: ((CaptureRequest) -> Void)?
    #endif

    @ObservationIgnored private var pending: CaptureRequest?
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func begin(_ request: CaptureRequest) {
        pending = request
        if defaults.bool(forKey: Self.tipsSeenKey) {
            Task { await proceed() }
        } else {
            showingTips = true
        }
    }

    func tipsFinished() {
        defaults.set(true, forKey: Self.tipsSeenKey)
        showingTips = false
    }

    /// Called when the tips sheet has finished dismissing, so the permission message or the camera is never
    /// presented while the sheet is still on its way out.
    func tipsDismissed() {
        if defaults.bool(forKey: Self.tipsSeenKey) {
            Task { await proceed() }
        } else {
            pending = nil
        }
    }

    private func proceed() async {
        guard let request = pending else { return }
        pending = nil
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            #if DEBUG
            simulatorCapture?(request)
            #else
            showingCameraUnavailable = true
            #endif
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraRequest = request
        case .notDetermined:
            if await AVCaptureDevice.requestAccess(for: .video) {
                cameraRequest = request
            } else {
                showingCameraOff = true
            }
        default:
            showingCameraOff = true
        }
    }
}
