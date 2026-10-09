import ExzemaCore
import SwiftUI

/// An area's photo thumbnails, one strip per slot and one more for a slot's close-ups, each ending in an add tile.
struct PhotoRows: View {
    let model: AppModel
    let area: Area

    var body: some View {
        let slots = model.photoSlots.filter { $0.areaID == area.id }
        ForEach(slots, id: \.id) { slot in
            PhotoStrip(model: model, slot: slot, kind: .photo, title: slots.count > 1 ? "\(slot.name) photos" : "Photos")
            if slot.offersCloseUp {
                PhotoStrip(model: model, slot: slot, kind: .closeUp, title: "Close-up")
            }
        }
    }
}

private enum PhotoTile {
    static let width: CGFloat = 64
    static let height: CGFloat = 80
}

private struct PhotoStrip: View {
    let model: AppModel
    let slot: PhotoSlot
    let kind: PhotoKind
    let title: String

    var body: some View {
        let photos = model.photos(in: slot, kind: kind)
        if model.canAddPhotos || !photos.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(photos, id: \.id) { photo in
                            PhotoThumbnail(model: model, photo: photo)
                        }
                        if model.canAddPhotos {
                            AddPhotoTile(model: model, slot: slot, kind: kind)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct AddPhotoTile: View {
    let model: AppModel
    let slot: PhotoSlot
    let kind: PhotoKind

    var body: some View {
        Button {
            model.photoFlow.begin(CaptureRequest(slot: slot, kind: kind))
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "camera").font(.title3)
                Text(kind == .closeUp ? "Add close-up" : "Add")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
            }
            .frame(width: PhotoTile.width, height: PhotoTile.height)
            .background(Color.secondary.opacity(0.12), in: .rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(kind == .closeUp ? "Add a close-up of \(slot.name)" : "Add a photo of \(slot.name)")
    }
}

/// A photo's thumbnail, replaced by a placeholder whenever the app is not active so the app switcher never
/// shows skin.
private struct PhotoThumbnail: View {
    let model: AppModel
    let photo: StoredPhoto
    @State private var image: UIImage?
    @Environment(\.scenePhase) private var scenePhase

    /// Names the slot, the kind, and the time taken, so photos in a row can be told apart without seeing them.
    private var accessibilityLabel: String {
        let slot = model.photoSlots.first { $0.id == photo.slotID }?.name ?? "Photo"
        let zone = TimeZone(identifier: photo.timeZoneIdentifier) ?? .current
        let time = photo.takenAt.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: zone))
        return "\(slot) \(photo.kind == .closeUp ? "close-up" : "photo"), taken \(time). Open"
    }

    var body: some View {
        Button {
            model.photoFlow.viewing = PhotoViewerTarget(slotID: photo.slotID, startID: photo.id)
        } label: {
            ZStack {
                Color.secondary.opacity(0.2)
                if scenePhase == .active, let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Image(systemName: "photo").foregroundStyle(.secondary)
                }
            }
            .frame(width: PhotoTile.width, height: PhotoTile.height)
            .clipShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .task(id: photo.fileName) { image = await model.thumbnail(for: photo) }
    }
}
