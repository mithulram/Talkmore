import AppKit
import SwiftUI

@main
struct TalkmoreApp: App {
    @State private var coordinator = AppCoordinator()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(coordinator: coordinator)
                .task { coordinator.start() }
        } label: {
            Image(systemName: coordinator.state.symbol)
                .accessibilityLabel("Talkmore")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(coordinator: coordinator)
                .frame(width: 520, height: 430)
        }
    }
}

struct MenuBarContent: View {
    let coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Talkmore")
                        .font(.headline)
                    Text(coordinator.state.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack {
                Text("Push to talk")
                Spacer()
                Text("fn")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
            }

            Toggle("Polish after instant insertion", isOn: Binding(
                get: { coordinator.refinementEnabled },
                set: { coordinator.refinementEnabled = $0 }
            ))

            if !coordinator.permissions.allRequiredPermissionsGranted {
                Button("Grant required permissions") {
                    Task { await coordinator.requestPermissions() }
                }
                .buttonStyle(.borderedProminent)
            }

            if !coordinator.lastTranscript.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Last dictation")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(coordinator.lastTranscript)
                        .font(.caption)
                        .lineLimit(3)
                        .textSelection(.enabled)
                    if !coordinator.lastLatencySummary.isEmpty {
                        Text(coordinator.lastLatencySummary)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Divider()

            HStack {
                SettingsLink { Text("Settings…") }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(width: 330)
    }
}

struct SettingsView: View {
    let coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Talkmore")
                    .font(.largeTitle.bold())
                Text("Private, on-device push-to-talk dictation.")
                    .foregroundStyle(.secondary)
            }

            GroupBox("Permissions") {
                VStack(spacing: 10) {
                    PermissionRow(label: "Microphone", granted: coordinator.permissions.microphoneGranted)
                    PermissionRow(label: "Speech Recognition", granted: coordinator.permissions.speechGranted)
                    PermissionRow(label: "Accessibility", granted: coordinator.permissions.accessibilityGranted)
                    PermissionRow(label: "Input Monitoring", granted: coordinator.permissions.inputMonitoringGranted)
                }
                .padding(.vertical, 5)
            }

            GroupBox("Local intelligence") {
                HStack {
                    Image(systemName: "apple.intelligence")
                    Text(coordinator.refiner.availabilityDescription)
                    Spacer()
                }
                .padding(.vertical, 5)
            }

            HStack {
                Button("Request permissions") {
                    Task { await coordinator.requestPermissions() }
                }
                .buttonStyle(.borderedProminent)

                Button("Refresh status") { coordinator.permissions.refresh() }
            }

            Spacer()

            Text("Hold fn, speak, then release to insert text into the focused app. If macOS also opens Emoji, Dictation, or input switching, set the Globe/fn key action to Do Nothing in Keyboard settings.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(28)
    }
}

private struct PermissionRow: View {
    let label: String
    let granted: Bool

    var body: some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(granted ? Color.green : Color.secondary)
            Text(label)
            Spacer()
            Text(granted ? "Allowed" : "Needed")
                .foregroundStyle(.secondary)
        }
    }
}
