import ApplicationServices
import AVFoundation
import CoreGraphics
import Observation
import Speech

@MainActor
@Observable
final class PermissionManager {
    private(set) var microphoneGranted = false
    private(set) var speechGranted = false
    private(set) var accessibilityGranted = false
    private(set) var inputMonitoringGranted = false

    var allRequiredPermissionsGranted: Bool {
        microphoneGranted && speechGranted && accessibilityGranted && inputMonitoringGranted
    }

    init() {
        refresh()
    }

    func refresh() {
        microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        speechGranted = SFSpeechRecognizer.authorizationStatus() == .authorized
        accessibilityGranted = AXIsProcessTrusted()
        inputMonitoringGranted = CGPreflightListenEventAccess()
    }

    func requestAll() async {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            microphoneGranted = await AVCaptureDevice.requestAccess(for: .audio)
        }

        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            speechGranted = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        }

        if !AXIsProcessTrusted() {
            let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            let options = [promptKey: true] as CFDictionary
            accessibilityGranted = AXIsProcessTrustedWithOptions(options)
        }

        if !CGPreflightListenEventAccess() {
            inputMonitoringGranted = CGRequestListenEventAccess()
        }

        refresh()
    }
}
