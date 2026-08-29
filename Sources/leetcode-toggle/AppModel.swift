import AppKit
import Foundation
import Combine

/// Central observable state: current snapshot, refresh state, timer.
///
/// Not actor-isolated on purpose (keeps SwiftUI/AppKit call sites simple
/// across SDK generations); all published mutations happen on the main
/// thread — network completions hop via `MainActor.run`.
final class AppModel: ObservableObject {

    @Published private(set) var snapshot: Snapshot?
    @Published private(set) var state: RefreshState = .idle

    let settings: SettingsStore

    private var refreshTask: Task<Void, Never>?
    private var timer: Timer?
    private let reentrant = NSLock()

    init(settings: SettingsStore) {
        self.settings = settings
    }

    // MARK: - Refresh

    /// Refresh immediately if idle/failed, otherwise keep the existing task.
    func refreshIfStale(maxAge: TimeInterval = 60) {
        switch state {
        case .loading:
            break
        case .idle, .failed:
            refresh()
        case .loaded(let at):
            if Date().timeIntervalSince(at) > maxAge { refresh() }
        }
    }

    func refresh() {
        guard reentrant.try() else { return }
        defer { reentrant.unlock() }

        guard settings.hasUsername else {
            snapshot = nil
            state = .failed("Add your LeetCode username in Settings.")
            return
        }
        let username = settings.trimmedUsername

        refreshTask?.cancel()
        state = .loading
        // Strong capture: the task runs briefly and releases us; the
        // temporary self↔task cycle is not a leak.
        let selfRef = self
        refreshTask = Task {
            do {
                let snap = try await LeetCodeAPI.snapshot(username: username)
                guard !Task.isCancelled else { return }
                let model = selfRef
                await MainActor.run {
                    model.snapshot = snap
                    model.state = .loaded(Date())
                }
            } catch {
                guard !Task.isCancelled else { return }
                let model = selfRef
                await MainActor.run {
                    model.state = .failed(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Timer

    func startTimer() {
        timer?.invalidate()
        let interval = settings.refreshInterval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.refresh() }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Actions

    func openTodayChallenge() {
        if let url = snapshot.flatMap({ URL(string: $0.challenge.url) }) {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(URL(string: "https://leetcode.com/problemset/dailychallenge/")!)
        }
    }

    func openProfile() {
        let username = settings.trimmedUsername
        guard !username.isEmpty else { return }
        NSWorkspace.shared.open(URL(string: "https://leetcode.com/\(username)/")!)
    }
}
