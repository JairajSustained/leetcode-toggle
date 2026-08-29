import AppKit
import SwiftUI

/// A minimal on-demand utility window (no dock icon, closes to hidden).
@MainActor
final class WindowController: NSObject, NSWindowDelegate {

    let window: NSWindow

    init(title: String, content: some View, contentSize: NSSize) {
        let hosting = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: hosting)
        self.window = window
        window.title = title
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(contentSize)
        window.level = .normal
        super.init()
        window.delegate = self
        window.center()
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    nonisolated func windowWillClose(_ notification: Notification) {}
}
