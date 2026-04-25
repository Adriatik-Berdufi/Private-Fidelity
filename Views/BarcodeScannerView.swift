import SwiftUI
import AVFoundation

struct BarcodeScannerView: UIViewControllerRepresentable {
    var onCodeScanned: (String) -> Void
    var onFailure: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let viewController = ScannerViewController()
        viewController.onCodeScanned = onCodeScanned
        viewController.onFailure = onFailure
        return viewController
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCodeScanned: ((String) -> Void)?
    var onFailure: ((String) -> Void)?

    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "private-fidelity.camera.session")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didScanCode = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureCaptureSession()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startSessionIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSessionIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    private func configureCaptureSession() {
        guard
            let usageDescription = Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") as? String,
            !usageDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            onFailure?("Permesso fotocamera non configurato. Aggiungi Privacy - Camera Usage Description nel target app.")
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSessionIfPossible()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.setupSessionIfPossible()
                    } else {
                        self.onFailure?("Permesso fotocamera negato. Abilitalo dalle impostazioni.")
                    }
                }
            }
        case .denied, .restricted:
            onFailure?("Permesso fotocamera non disponibile. Controlla le impostazioni privacy.")
        @unknown default:
            onFailure?("Stato fotocamera non supportato.")
        }
    }

    private func setupSessionIfPossible() {
        guard previewLayer == nil else {
            return
        }

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
#if targetEnvironment(simulator)
            onFailure?("Stai usando il simulatore iOS: la fotocamera non e disponibile. Usa un iPhone reale oppure inserisci il codice a mano.")
#else
            onFailure?("Fotocamera non trovata su questo dispositivo.")
#endif
            return
        }

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)

            guard captureSession.canAddInput(videoInput) else {
                onFailure?("Impossibile leggere input video.")
                return
            }
            captureSession.addInput(videoInput)

            let metadataOutput = AVCaptureMetadataOutput()
            guard captureSession.canAddOutput(metadataOutput) else {
                onFailure?("Impossibile leggere i metadati del codice.")
                return
            }
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
            metadataOutput.metadataObjectTypes = [
                .ean8, .ean13, .code39, .code93, .code128,
                .upce, .itf14, .pdf417, .aztec, .dataMatrix, .qr
            ]

            let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = view.layer.bounds
            view.layer.addSublayer(previewLayer)
            self.previewLayer = previewLayer

            startSessionIfNeeded()
        } catch {
            onFailure?("Errore configurazione fotocamera: \(error.localizedDescription)")
        }
    }

    private func startSessionIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }

    private func stopSessionIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didScanCode else {
            return
        }

        guard
            let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            let code = metadataObject.stringValue,
            !code.isEmpty
        else {
            return
        }

        didScanCode = true
        stopSessionIfNeeded()
        onCodeScanned?(code)
    }
}
