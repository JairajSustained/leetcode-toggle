import AppKit
import Combine
import SwiftUI

/// Owns the NSStatusItem, its menu, and the two utility windows.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var settingsWindow: WindowController?
    private var activityWindow: WindowController?
    private var cancellables = Set<AnyCancellable>()

    var settings: SettingsStore!
    var model: AppModel!

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = SettingsStore()
        self.settings = settings
        self.model = AppModel(settings: settings)

        setupStatusItem()
        updateIcon()
        model.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.updateIcon() }
            }
            .store(in: &cancellables)
        model.startTimer()
        model.refresh()
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = MenuIcon.image(for: .plain)
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "LeetCode — daily challenge"
        }
    }

    private func updateIcon() {
        let state: IconState
        switch model.state {
        case .failed where model.snapshot == nil:
            state = .error
        default:
            state = model.snapshot?.didSolveToday == true ? .done : .plain
        }
        statusItem.button?.image = MenuIcon.image(for: state)

        if let snap = model.snapshot {
            statusItem.button?.toolTip = "LeetCode — \(snap.challenge.title) — \(snap.didSolveToday ? "solved today ✓" : "not solved yet")"
        }
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            primaryAction()
        }
    }

    /// Left click: jump straight to today's challenge.
    private func primaryAction() {
        if model.settings.hasUsername {
            model.openTodayChallenge()
        } else {
            openSettings()
        }
    }

    // MARK: - Menu (right click)

    private func showMenu() {
        model.refreshIfStale()
        let menu = buildMenu()
        if let button = statusItem.button {
            menu.popUp(positioning: nil,
                       at: NSPoint(x: 0, y: button.bounds.maxY + 5),
                       in: button)
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        func info(_ title: String, attributed: NSAttributedString? = nil) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.isEnabled = false
            if let attributed { item.attributedTitle = attributed }
            return item
        }
        func action(_ title: String, _ selector: Selector, _ key: String = "") -> NSMenuItem {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
            item.target = self
            item.isEnabled = true
            return item
        }

        guard model.settings.hasUsername else {
            menu.addItem(info("LeetCode Toggle"))
            menu.addItem(info("Add your LeetCode username to get started."))
            menu.addItem(.separator())
            menu.addItem(action("Settings…", #selector(openSettings), ","))
            menu.addItem(.separator())
            menu.addItem(action("Quit", #selector(quit), "q"))
            return menu
        }

        switch model.state {
        case .failed(let message) where model.snapshot == nil:
            menu.addItem(info("LeetCode — \(model.settings.trimmedUsername)"))
            menu.addItem(info("⚠️ \(message)"))
            menu.addItem(.separator())
            menu.addItem(action("Retry", #selector(manualRefresh), "r"))
            menu.addItem(action("Settings…", #selector(openSettings), ","))
            menu.addItem(.separator())
            menu.addItem(action("Quit", #selector(quit), "q"))
            return menu

        case .loading where model.snapshot == nil:
            menu.addItem(info("LeetCode — \(model.settings.trimmedUsername)"))
            menu.addItem(info("Loading…"))
            menu.addItem(.separator())
            menu.addItem(action("Settings…", #selector(openSettings), ","))
            menu.addItem(.separator())
            menu.addItem(action("Quit", #selector(quit), "q"))
            return menu

        default:
            break
        }

        guard let snap = model.snapshot else {
            menu.addItem(info("LeetCode — \(model.settings.trimmedUsername)"))
            menu.addItem(.separator())
            menu.addItem(action("Refresh", #selector(manualRefresh), "r"))
            menu.addItem(action("Settings…", #selector(openSettings), ","))
            menu.addItem(.separator())
            menu.addItem(action("Quit", #selector(quit), "q"))
            return menu
        }

        // Today's challenge
        let title = snap.challenge.title
        let shortTitle = title.count > 40 ? String(title.prefix(40)) + "…" : title
        menu.addItem(info("Today: \(shortTitle)"))
        let statusColor: NSColor = snap.didSolveToday ? .systemGreen : .secondaryLabelColor
        menu.addItem(info(
            snap.didSolveToday ? "✓ Solved today" : "Not solved yet",
            attributed: NSAttributedString(string: snap.didSolveToday ? "✓ Solved today" : "Not solved yet",
                                           attributes: [.foregroundColor: statusColor])
        ))
        if case .failed(let message) = model.state {
            menu.addItem(info("⚠️ Refresh failed — showing last data"))
            menu.addItem(info(message))
        }
        menu.addItem(.separator())

        // Streak & stats
        menu.addItem(info("🔥 Streak: \(snap.streakDays) \(snap.streakDays == 1 ? "day" : "days")"))
        menu.addItem(info("Solved: \(snap.solvedCount) · Submissions: \(snap.totalSubmissions)"))
        menu.addItem(.separator())

        // When you coded — last 7 days
        menu.addItem(info("Last 7 days"))
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        for entry in snap.lastSevenDaysActivity {
            let day = formatter.string(from: entry.date)
            let countText = entry.count == 0 ? "–" : "\(entry.count) \(entry.count == 1 ? "problem" : "problems")"
            menu.addItem(info("\(day)   \(countText)"))
        }
        menu.addItem(.separator())

        // Deep links
        menu.addItem(action("Activity Calendar…", #selector(openActivity)))
        menu.addItem(action("Open Today's Challenge", #selector(openChallenge)))
        menu.addItem(action("Open My Profile", #selector(openProfile)))
        menu.addItem(.separator())

        menu.addItem(action("Refresh", #selector(manualRefresh), "r"))
        menu.addItem(action("Settings…", #selector(openSettings), ","))
        menu.addItem(.separator())
        menu.addItem(action("Quit", #selector(quit), "q"))

        return menu
    }

    // MARK: - Menu actions

    @objc private func manualRefresh() {
        model.refresh()
    }

    @objc private func openChallenge() {
        model.openTodayChallenge()
    }

    @objc private func openProfile() {
        model.openProfile()
    }

    @objc private func openActivity() {
        model.refreshIfStale()
        if activityWindow == nil {
            activityWindow = WindowController(
                title: "LeetCode Activity",
                content: ActivityView(model: model),
                contentSize: NSSize(width: 460, height: 600)
            )
        }
        activityWindow?.show()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = WindowController(
                title: "LeetCode Toggle Settings",
                content: SettingsView(settings: settings, model: model),
                contentSize: NSSize(width: 400, height: 400)
            )
        }
        settingsWindow?.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
