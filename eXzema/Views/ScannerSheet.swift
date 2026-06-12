import SwiftUI
import VisionKit

/// Live-camera scanner for ingredient labels and barcodes, built on
/// VisionKit's DataScannerViewController. All recognition happens on-device.
/// Tap pieces of label text to collect them, or tap a barcode to look the
/// product up in the bundled offline database.
struct ScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    /// Called with collected label text (comma-joined) when the user taps "Use".
    var onText: (String) -> Void
    /// Called when a tapped barcode matches the offline database. The sheet
    /// dismisses itself after calling this.
    var onProduct: ((BarcodeProduct) -> Void)? = nil

    @State private var captured: [String] = []
    @State private var barcodeStatus: String?

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    VStack(spacing: 0) {
                        IngredientScannerView(
                            onTapText: { text in
                                if !captured.contains(text) {
                                    captured.append(text)
                                }
                            },
                            onTapBarcode: handleBarcode
                        )
                        if let barcodeStatus {
                            Text(barcodeStatus)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.bar)
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
                        description: Text("Live scanning needs a device with a camera. You can type or paste the ingredient list instead.")
                    )
                }
            }
            .navigationTitle("Scan label or barcode")
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

    private func handleBarcode(_ payload: String) {
        if let product = BarcodeLookup.lookup(payload) {
            if let onProduct {
                onProduct(product)
                dismiss()
            } else {
                onText(product.ingredientsText)
                dismiss()
            }
        } else {
            barcodeStatus = "Barcode \(payload) isn't in the offline database (\(BarcodeLookup.productCount) products). Scan the ingredient text instead."
        }
    }
}

private struct IngredientScannerView: UIViewControllerRepresentable {
    var onTapText: (String) -> Void
    var onTapBarcode: (String) -> Void

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

    func makeCoordinator() -> Coordinator {
        Coordinator(onTapText: onTapText, onTapBarcode: onTapBarcode)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onTapText: (String) -> Void
        let onTapBarcode: (String) -> Void

        init(onTapText: @escaping (String) -> Void, onTapBarcode: @escaping (String) -> Void) {
            self.onTapText = onTapText
            self.onTapBarcode = onTapBarcode
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            switch item {
            case .text(let text):
                onTapText(text.transcript)
            case .barcode(let barcode):
                if let payload = barcode.payloadStringValue {
                    onTapBarcode(payload)
                }
            @unknown default:
                break
            }
        }
    }
}
