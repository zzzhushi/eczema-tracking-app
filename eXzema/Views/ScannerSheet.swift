import SwiftUI
import VisionKit

/// Live-camera scanner for ingredient labels and barcodes, built on
/// VisionKit's DataScannerViewController. All recognition happens on-device.
/// Tap pieces of text (or a barcode) to collect them, then "Use".
struct ScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onText: (String) -> Void
    @State private var captured: [String] = []

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    VStack(spacing: 0) {
                        IngredientScannerView { text in
                            if !captured.contains(text) {
                                captured.append(text)
                            }
                        }
                        if !captured.isEmpty {
                            HStack {
                                Text("\(captured.count) captured")
                                    .font(.callout)
                                Spacer()
                                Button("Clear") { captured.removeAll() }
                                    .font(.callout)
                            }
                            .padding()
                            .background(.bar)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "Scanner unavailable",
                        systemImage: "camera",
                        description: Text("Live text scanning needs a device with a camera. You can type or paste the ingredient list instead.")
                    )
                }
            }
            .navigationTitle("Scan label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use \(captured.count)") {
                        onText(captured.joined(separator: ", "))
                        dismiss()
                    }
                    .disabled(captured.isEmpty)
                }
            }
        }
    }
}

private struct IngredientScannerView: UIViewControllerRepresentable {
    var onTap: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text(), .barcode()],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        if !scanner.isScanning {
            try? scanner.startScanning()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onTap: (String) -> Void

        init(onTap: @escaping (String) -> Void) {
            self.onTap = onTap
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            switch item {
            case .text(let text):
                onTap(text.transcript)
            case .barcode(let barcode):
                if let payload = barcode.payloadStringValue {
                    onTap(payload)
                }
            @unknown default:
                break
            }
        }
    }
}
