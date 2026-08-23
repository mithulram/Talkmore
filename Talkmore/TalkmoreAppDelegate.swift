import AppKit
import SwiftUI

@MainActor
final class TalkmoreAppDelegate: NSObject, NSApplicationDelegate {
    let coordinator = AppCoordinator()

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var settingsWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        configurePopover()
        coordinator.start()

#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--show-menu-for-testing") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
                self?.showPopover()
            }
        }
#endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(
            systemSymbolName: "waveform.circle.fill",
            accessibilityDescription: "Talkmore"
        )
        button.imagePosition = .imageOnly
        button.toolTip = "Talkmore — hold fn to dictate"
        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = false

        let controller = NSHostingController(
            rootView: MenuBarContent(
                coordinator: coordinator,
                openSettings: { [weak self] in self?.showSettings() },
                quitApplication: { NSApplication.shared.terminate(nil) }
            )
        )
        controller.sizingOptions = [.preferredContentSize]
        popover.contentViewController = controller
    }

    @objc private func togglePopover() {
        popover.isShown ? popover.performClose(nil) : showPopover()
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        NSApplication.shared.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func showSettings() {
        popover.performClose(nil)

        if let window = settingsWindowController?.window {
            NSApplication.shared.activate()
            window.makeKeyAndOrderFront(nil)
            return
        }

        let content = SettingsView(coordinator: coordinator)
            .frame(minWidth: 760, minHeight: 590)
        let hostingController = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Talkmore Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 760, height: 590))
        window.minSize = NSSize(width: 680, height: 520)
        window.isReleasedWhenClosed = false
        window.center()

        let windowController = NSWindowController(window: window)
        settingsWindowController = windowController
        NSApplication.shared.activate()
        windowController.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }
}
