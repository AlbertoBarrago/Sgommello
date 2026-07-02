import AVFoundation
import Vision
import QuartzCore

// MARK: - Presence Monitor

/// Watches the webcam while the overlay is on screen: if no face shows up
/// for a few seconds, the user genuinely stood up and Sgommello calms down.
/// The camera runs ONLY between start() and stop() — never in the background.
final class PresenceMonitor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "sgommello.presence")
    private var configured = false
    private var running = false
    /// True while we believe the user is away from the desk.
    private var userGone = false
    private var lastSampleAt: CFTimeInterval = 0
    private var lastFaceAt: CFTimeInterval = 0

    /// Seconds without a detected face before declaring the user gone.
    private let absenceThreshold: CFTimeInterval = 5
    /// Both called on the main queue. The monitor keeps watching after the
    /// user leaves, so it can also announce when they sit back down.
    var onUserLeft: (() -> Void)?
    var onUserReturned: (() -> Void)?

    /// Triggers the system camera-permission prompt if not yet determined.
    /// Called when the user flips the webcam toggle on, so the prompt shows
    /// up right there in the settings instead of mid-appearance later.
    static func requestPermissionIfNeeded() {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined else { return }
        AVCaptureDevice.requestAccess(for: .video) { _ in }
    }

    func start() {
        guard AppSettings.shared.presenceEnabled, !running else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            run()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard granted else { return }
                DispatchQueue.main.async { self?.run() }
            }
        default:
            // Denied/restricted: the safe zone stays the only way out.
            break
        }
    }

    func stop() {
        guard running else { return }
        running = false
        queue.async { self.session.stopRunning() }
    }

    private func run() {
        guard !running else { return }
        if !configured {
            configure()
        }
        guard configured else { return }
        userGone = false
        lastFaceAt = CACurrentMediaTime()
        running = true
        queue.async { self.session.startRunning() }
    }

    private func configure() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        // Face detection doesn't need resolution: keep the pipeline cheap.
        if session.canSetSessionPreset(.vga640x480) {
            session.sessionPreset = .vga640x480
        }
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        configured = true
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let now = CACurrentMediaTime()
        // Vision is expensive: sample roughly twice per second, drop the rest.
        guard running, now - lastSampleAt >= 0.5 else { return }
        lastSampleAt = now
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectFaceRectanglesRequest()
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up).perform([request])
        if let faces = request.results, !faces.isEmpty {
            lastFaceAt = now
            if userGone {
                userGone = false
                DispatchQueue.main.async { [weak self] in self?.onUserReturned?() }
            }
        } else if !userGone, now - lastFaceAt >= absenceThreshold {
            userGone = true
            DispatchQueue.main.async { [weak self] in self?.onUserLeft?() }
        }
    }
}
