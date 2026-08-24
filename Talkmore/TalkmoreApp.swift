import AppKit
import SwiftUI

@main
struct TalkmoreApp: App {
    @NSApplicationDelegateAdaptor(TalkmoreAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(coordinator: appDelegate.coordinator)
                .frame(width: 760, height: 590)
        }
    }
}

struct MenuBarContent: View {
    let coordinator: AppCoordinator
    let openSettings: () -> Void
    let quitApplication: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image("BrandIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Talkmore")
                        .font(.headline)
                    HStack(spacing: 5) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 7, height: 7)
                        Text(coordinator.state.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text("LOCAL")
                    .font(.caption2.bold())
                    .foregroundStyle(.indigo)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(.indigo.opacity(0.11), in: Capsule())
            }

            HStack {
                Label("Hold to talk", systemImage: "waveform")
                    .font(.callout.weight(.medium))
                Spacer()
                Text("fn")
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(11)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 10) {
                Image(systemName: coordinator.settings.writingStyle.symbol)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text("Writing style")
                    .font(.callout.weight(.medium))
                Spacer()
                Picker("Writing style", selection: Binding(
                    get: { coordinator.settings.writingStyle },
                    set: { coordinator.settings.writingStyle = $0 }
                )) {
                    ForEach(WritingStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 132)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))

            if coordinator.setupNeedsAttention {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Setup needs attention", systemImage: "exclamationmark.shield.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    Button("Finish setup") {
                        Task { await coordinator.requestPermissions() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }

            if !coordinator.lastTranscript.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("LAST DICTATION")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            coordinator.copyLastTranscript()
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.plain)
                        .help("Copy last dictation")
                    }
                    Text(coordinator.lastTranscript)
                        .font(.callout)
                        .lineLimit(4)
                        .textSelection(.enabled)
                    if !coordinator.lastLatencySummary.isEmpty {
                        Text(coordinator.lastLatencySummary)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    if !coordinator.lastCompatibilitySummary.isEmpty {
                        Text(coordinator.lastCompatibilitySummary)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                .padding(11)
                .background(.quaternary.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
            }

            Text(coordinator.lastDiagnostic)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)

            Divider()

            HStack {
                Button(action: openSettings) {
                    Label("Settings", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)
                Spacer()
                Button("Quit", action: quitApplication)
                    .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .frame(width: 350)
    }

    private var statusColor: Color {
        switch coordinator.state {
        case .idle: .green
        case .error: .red
        default: .indigo
        }
    }
}

struct SettingsView: View {
    let coordinator: AppCoordinator

    var body: some View {
        TabView {
            GeneralSettingsView(coordinator: coordinator)
                .tabItem { Label("General", systemImage: "slider.horizontal.3") }

            DictionarySettingsView(coordinator: coordinator)
                .tabItem { Label("Dictionary", systemImage: "text.book.closed") }

            HistorySettingsView(coordinator: coordinator)
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

            AboutSettingsView(coordinator: coordinator)
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .padding(16)
    }
}

private struct GeneralSettingsView: View {
    let coordinator: AppCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ProductHeader(
                    title: "Make every word land right",
                    subtitle: "Private, on-device dictation tuned to the app beneath your cursor."
                )

                HStack(alignment: .top, spacing: 16) {
                    SettingsCard(title: "Writing", symbol: "text.cursor") {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Style", selection: Binding(
                                get: { coordinator.settings.writingStyle },
                                set: { coordinator.settings.writingStyle = $0 }
                            )) {
                                ForEach(WritingStyle.allCases) { style in
                                    Text(style.title).tag(style)
                                }
                            }

                            Text(coordinator.settings.writingStyle.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Label(coordinator.recognitionStatusDescription, systemImage: "waveform.and.mic")
                                .font(.callout)

                            Toggle("Polish after instant insertion", isOn: Binding(
                                get: { coordinator.refinementEnabled },
                                set: { coordinator.refinementEnabled = $0 }
                            ))
                            Toggle("Developer mode in coding apps", isOn: Binding(
                                get: { coordinator.developerModeEnabled },
                                set: { coordinator.developerModeEnabled = $0 }
                            ))
                        }
                    }

                    SettingsCard(title: "Listening overlay", symbol: "waveform.badge.mic") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Show while dictating", isOn: Binding(
                                get: { coordinator.settings.showOverlay },
                                set: { coordinator.settings.showOverlay = $0 }
                            ))
                            Picker("Position", selection: Binding(
                                get: { coordinator.settings.overlayPlacement },
                                set: { coordinator.settings.overlayPlacement = $0 }
                            )) {
                                ForEach(OverlayPlacement.allCases) { placement in
                                    Text(placement.title).tag(placement)
                                }
                            }
                            .disabled(!coordinator.settings.showOverlay)

                            Toggle("Save private local history", isOn: Binding(
                                get: { coordinator.settings.saveHistory },
                                set: { coordinator.settings.saveHistory = $0 }
                            ))

                            Text("Audio and transcripts never leave this Mac. History is stored locally in Talkmore preferences.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                SettingsCard(title: "Setup", symbol: "checkmark.shield") {
                    VStack(spacing: 10) {
                        PermissionRow(label: "Microphone", granted: coordinator.permissions.microphoneGranted)
                        PermissionRow(label: "Speech Recognition fallback", granted: coordinator.permissions.speechGranted)
                        PermissionRow(label: "Accessibility", granted: coordinator.permissions.accessibilityGranted)
                        PermissionRow(label: "Input Monitoring", granted: coordinator.permissions.inputMonitoringGranted)
                        Divider()
                        HStack {
                            Label(coordinator.refiner.availabilityDescription, systemImage: "apple.intelligence")
                                .font(.callout)
                            Spacer()
                            Button("Request permissions") {
                                Task { await coordinator.requestPermissions() }
                            }
                            .buttonStyle(.borderedProminent)
                            Button("Refresh") { coordinator.permissions.refresh() }
                        }
                    }
                }

                HStack(spacing: 20) {
                    OnboardingStep(number: "1", title: "Hold fn", detail: "The overlay responds instantly.")
                    OnboardingStep(number: "2", title: "Speak naturally", detail: "Talkmore stays completely local.")
                    OnboardingStep(number: "3", title: "Release", detail: "Text lands at the cursor in under 0.5s.")
                }
            }
            .padding(8)
        }
    }
}

private struct DictionarySettingsView: View {
    let coordinator: AppCoordinator
    @State private var spokenForm = ""
    @State private var replacement = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ProductHeader(
                title: "Your words, spelled your way",
                subtitle: "Teach Talkmore names, products, acronyms, and specialist vocabulary."
            )

            HStack(spacing: 10) {
                TextField("What you say — e.g. open AI", text: $spokenForm)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                TextField("What Talkmore writes — e.g. OpenAI", text: $replacement)
                Button("Add") { addEntry() }
                    .buttonStyle(.borderedProminent)
                    .disabled(spokenForm.trimmingCharacters(in: .whitespaces).isEmpty || replacement.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .onSubmit(addEntry)

            if coordinator.personalDictionary.entries.isEmpty {
                ContentUnavailableView(
                    "No custom words yet",
                    systemImage: "text.book.closed",
                    description: Text("Add a spoken form and the exact spelling you want inserted.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(coordinator.personalDictionary.entries) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.spokenForm)
                                    .font(.callout)
                                Text("writes as \(entry.replacement)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(entry.replacement)
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(.quaternary, in: Capsule())
                            Button(role: .destructive) {
                                coordinator.personalDictionary.remove(id: entry.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
            }

            Text("Dictionary entries are applied locally before insertion and are also supplied to Apple Speech as recognition hints.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
    }

    private func addEntry() {
        guard coordinator.personalDictionary.add(
            spokenForm: spokenForm,
            replacement: replacement
        ) else { return }
        spokenForm = ""
        replacement = ""
    }
}

private struct HistorySettingsView: View {
    let coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                ProductHeader(
                    title: "Recent dictations",
                    subtitle: "Up to 50 private, local entries—never synced or uploaded."
                )
                Spacer()
                Button("Clear history", role: .destructive) {
                    coordinator.history.clear()
                }
                .disabled(coordinator.history.items.isEmpty)
            }

            if coordinator.history.items.isEmpty {
                ContentUnavailableView(
                    "No dictations yet",
                    systemImage: "waveform",
                    description: Text("Your recent dictations will appear here when local history is enabled.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(coordinator.history.items) { item in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(item.applicationName)
                                .font(.caption.weight(.semibold))
                            Text(item.writingStyle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(item.createdAt, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.2fs", item.visibleLatency))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(item.visibleLatency < 0.5 ? Color.green : Color.orange)
                            Button {
                                coordinator.copyToClipboard(item.text)
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.borderless)
                        }
                        Text(item.text)
                            .font(.callout)
                            .lineLimit(3)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 5)
                }
                .listStyle(.inset)
            }
        }
        .padding(8)
    }
}

private struct AboutSettingsView: View {
    let coordinator: AppCoordinator

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image("BrandIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 128, height: 128)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: .indigo.opacity(0.25), radius: 22, y: 8)
            VStack(spacing: 6) {
                Text("Talkmore")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("Speak. Release. Keep moving.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            Text("A private, local-first push-to-talk dictation app for macOS. Apple Speech handles recognition on device; optional Apple Intelligence polish runs after instant insertion.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 500)
            HStack(spacing: 24) {
                Label("No account", systemImage: "person.crop.circle.badge.xmark")
                Label("No cloud audio", systemImage: "icloud.slash")
                Label("< 0.5s target", systemImage: "bolt.fill")
            }
            .font(.callout.weight(.medium))
            Text("Version 0.2.0 · Built for this Mac")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(8)
    }
}

private struct ProductHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image("BrandIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.bold())
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let symbol: String
    let content: Content

    init(title: String, symbol: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.symbol = symbol
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label(title, systemImage: symbol)
                .font(.headline)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 15))
    }
}

private struct PermissionRow: View {
    let label: String
    let granted: Bool

    var body: some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(granted ? Color.green : Color.orange)
            Text(label)
            Spacer()
            Text(granted ? "Allowed" : "Needed")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct OnboardingStep: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(.indigo, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.callout.bold())
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
