import AVFoundation
import SwiftUI

/// Experiment: the Duo's outer screen is only reachable while a camera capture session runs
/// (CameraCaptureAccessory). This starts a minimal session and reports what the simulator offers.
final class CrowdCam {
    static let shared = CrowdCam()
    let session = AVCaptureSession()
    private(set) var running = false

    func start() {
        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera, .external], mediaType: .video, position: .unspecified)
        let names = discovery.devices.map { "\($0.localizedName)|\($0.position.rawValue)" }
        DebugLog.event("cam_devices", ["count": names.count, "devices": names])
        guard let device = discovery.devices.first(where: { $0.position == .back }) ?? discovery.devices.first,
              let input = try? AVCaptureDeviceInput(device: device) else {
            DebugLog.event("cam_start", ["ok": false, "reason": "no device"])
            return
        }
        session.beginConfiguration()
        if session.canAddInput(input) { session.addInput(input) }
        session.commitConfiguration()
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            session.startRunning()
            running = session.isRunning
            DebugLog.event("cam_start", ["ok": session.isRunning, "device": device.localizedName])
        }
    }
}
