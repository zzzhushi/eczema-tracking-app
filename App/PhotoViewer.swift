import ExzemaCore
import SwiftUI

/// A slot's photos for one day, full screen: pinch to zoom, swipe between photos, delete.
struct PhotoViewer: View {
    let model: AppModel
    let target: PhotoViewerTarget
    @State private var selection: Int64?
    @State private var confirmingDelete = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    private var photos: [StoredPhoto] { model.photos.filter { $0.slotID == target.slotID } }

    private var current: StoredPhoto? {
        photos.first { $0.id == (selection ?? target.startID) } ?? photos.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if scenePhase == .active {
                    TabView(selection: $selection) {
                        ForEach(photos, id: \.id) { photo in
                            ZoomablePhoto(model: model, photo: photo).tag(Optional(photo.id))
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                } else {
                    Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .safeAreaInset(edge: .bottom) { caption }
            .navigationTitle(current.map(title) ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) { confirmingDelete = true } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Delete photo")
                }
            }
            .confirmationDialog("Delete this photo?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete photo", role: .destructive) { deleteCurrent() }
            } message: {
                Text("The photo is removed from this phone and can't be recovered.")
            }
            .onChange(of: photos.isEmpty) { _, empty in
                if empty { dismiss() }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { selection = target.startID }
    }

    @ViewBuilder private var caption: some View {
        if let photo = current {
            let zone = TimeZone(identifier: photo.timeZoneIdentifier) ?? .current
            VStack(spacing: 2) {
                Text("Taken \(photo.takenAt.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, timeZone: zone)))")
                if Day(loggedAt: photo.takenAt, in: zone).date != photo.date {
                    Text("Filed under \(photo.date.longTitle)")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }

    private func title(for photo: StoredPhoto) -> String {
        let name = model.photoSlots.first { $0.id == photo.slotID }?.name ?? "Photo"
        return photo.kind == .closeUp ? "\(name) close-up" : name
    }

    private func deleteCurrent() {
        guard let current else { return }
        let index = photos.firstIndex(of: current) ?? 0
        let remaining = photos.filter { $0.id != current.id }
        selection = remaining.isEmpty ? nil : remaining[min(index, remaining.count - 1)].id
        model.deletePhoto(current)
    }
}

private struct ZoomablePhoto: View {
    let model: AppModel
    let photo: StoredPhoto
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                ZoomableImage(image: image)
            } else {
                ProgressView().tint(.white)
            }
        }
        .task(id: photo.fileName) { image = await model.image(for: photo) }
    }
}

/// An image in a scroll view that zooms by pinch and by double tap.
private struct ZoomableImage: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> ZoomScrollView {
        let scroll = ZoomScrollView()
        scroll.delegate = context.coordinator
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 5
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.imageView.contentMode = .scaleAspectFit
        scroll.imageView.image = image
        scroll.addSubview(scroll.imageView)
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTapped(_:)))
        doubleTap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(doubleTap)
        return scroll
    }

    func updateUIView(_ scroll: ZoomScrollView, context: Context) {
        scroll.imageView.image = image
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            (scrollView as? ZoomScrollView)?.imageView
        }

        @objc func doubleTapped(_ gesture: UITapGestureRecognizer) {
            guard let scroll = gesture.view as? ZoomScrollView else { return }
            if scroll.zoomScale > 1 {
                scroll.setZoomScale(1, animated: true)
                return
            }
            let point = gesture.location(in: scroll.imageView)
            let size = CGSize(width: scroll.bounds.width / 2.5, height: scroll.bounds.height / 2.5)
            scroll.zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height), animated: true)
        }
    }
}

private final class ZoomScrollView: UIScrollView {
    let imageView = UIImageView()

    override func layoutSubviews() {
        super.layoutSubviews()
        if zoomScale == 1 { imageView.frame = bounds }
    }
}
