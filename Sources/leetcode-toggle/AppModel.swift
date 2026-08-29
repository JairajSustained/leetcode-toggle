import AppKit
import Foundation
import Combine

/// Central observable state: current snapshot, refresh state, timer.
@MainActor
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
        let username = settings.username.trimmingCharacters(in: .whitespaces)

        refreshTask?.cancel()
        state = .loading
        refreshTask = Task { [weak self] in
            do {
                let snap = try await LeetCodeAPI.snapshot(username: username)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.snapshot = snap
                    self?.state = .loaded(Date())
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.state = .failed(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Timer

    func startTimer() {
        timer?.invalidate()
        let interval = settings.refreshInterval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
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
        let username = settings.username.trimmingCharacters(in: .whitespaces)
        guard !username.isEmpty else { return }
        NSWorkspace.shared.open(URL(string: "https://leetcode.com/\(username)/")!)
    }
}
