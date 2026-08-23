import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class OverlayModel {
    var state: DictationState = .idle
    var transcript = ""
    var audioLevel: Float = 0
}

@MainActor
final class OverlayController {
    let model = OverlayModel()
    private var panel: NSPanel?

    func show(
        state: DictationState,
        transcript: String = "",
        placement: OverlayPlacement = .bottom
    ) {
        model.state = state
        model.transcript = transcript

        let panel = panel ?? makePanel()
        position(panel, placement: placement)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func update(state: DictationState? = nil, transcript: String? = nil, audioLevel: Float? = nil) {
        if let state { model.state = state }
        if let transcript { model.transcript = transcript }
        if let audioLevel { model.audioLevel = audioLevel }
    }

    func hide() {
        panel?.orderOut(nil)
        model.state = .idle
        model.transcript = ""
        model.audioLevel = 0
    }

    private func makePanel() -> NSPanel {
        let size = NSSize(width: 440, height: 84)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(rootView: RecordingOverlayView(model: model))
        return panel
    }

    private func position(_ panel: NSPanel, placement: OverlayPlacement) {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let x = frame.midX - panel.frame.width / 2
        let y: CGFloat = switch placement {
        case .bottom: frame.minY + 46
        case .center: frame.midY - panel.frame.height / 2
        case .top: frame.maxY - panel.frame.height - 46
        }
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

struct RecordingOverlayView: View {
    let model: OverlayModel

    var body: some View {
        HStack(spacing: 14) {
            Image("BrandIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(model.state == .recording ? Color.red : Color.indigo)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(model.state.title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            if model.state == .recording {
                VoiceLevelView(level: model.audioLevel)
                    .frame(width: 116, height: 38)
            }
        }
        .padding(.horizontal, 18)
        .frame(width: 440, height: 84)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        }
        .padding(4)
    }

    private var subtitle: String {
        switch model.state {
        case .idle: "Hold fn and speak"
        case .preparing: "Preparing local speech recognition"
        case .recording: "Release fn to insert"
        case .finalizing: "Finishing the last words"
        case .refining: "Polishing locally"
        case .inserting: "Putting text at your cursor"
        case .error: model.transcript
        }
    }
}

private struct VoiceLevelView: View {
    let level: Float
    private let shapes: [CGFloat] = [0.42, 0.68, 0.88, 0.62, 1, 0.72, 0.9, 0.58, 0.4]

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(shapes.indices, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(Color.accentColor.gradient)
                    .frame(
                        width: 5,
                        height: 5 + CGFloat(level) * 30 * shapes[index]
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.smooth(duration: 0.08), value: level)
    }
}
