import ExzemaCore
import SwiftUI

/// Presents the photo flow's screens over the day screen: the tips, the camera, the viewer, and the permission
/// messages. Each presentation hangs off its own anchor because SwiftUI keeps only one per view.
struct PhotoFlowPresenter: ViewModifier {
    let model: AppModel
    @Bindable private var flow: PhotoFlow

    init(model: AppModel) {
        self.model = model
        flow = model.photoFlow
    }

    func body(content: Content) -> some View {
        content
            .background {
                Color.clear.sheet(isPresented: $flow.showingTips, onDismiss: { flow.tipsDismissed() }) {
                    NavigationStack {
                        PhotoTipsView(onContinue: { flow.tipsFinished() })
                    }
                    .interactiveDismissDisabled()
                }
            }
            .background {
                Color.clear.fullScreenCover(item: $flow.cameraRequest) { request in
                    CameraPicker(
                        device: request.slot.presetCamera == .front ? .front : .rear,
                        onCapture: { image, metadata in
                            flow.cameraRequest = nil
                            model.addPhoto(CapturedPhoto(image: image), metadata: metadata, request: request)
                        },
                        onCancel: { flow.cameraRequest = nil }
                    )
                    .ignoresSafeArea()
                }
            }
            .background {
                Color.clear.fullScreenCover(item: $flow.viewing) { target in
                    PhotoViewer(model: model, target: target)
                }
            }
            .alert("Camera access is off", isPresented: $flow.showingCameraOff) {
                Button("Open iOS Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("eXzema can't take photos until the camera is allowed in iOS Settings.")
            }
            .alert("Camera not available", isPresented: $flow.showingCameraUnavailable) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This device has no camera eXzema can use.")
            }
    }
}
