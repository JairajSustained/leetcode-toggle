import AppKit

// Menu-bar-only app: no dock icon (LSUIElement in the .app bundle,
// plus an explicit accessory policy so it also behaves when run as a
// raw binary during development).

// Top-level code runs on the main thread; assumeIsolated lets us
// construct the @MainActor app delegate here.
MainActor.assumeIsolated {
    let args = CommandLine.arguments

    // CLI hook for asset previews: leetcode-toggle --icon-preview <dir>
    if let idx = args.firstIndex(of: "--icon-preview"), idx + 1 < args.count {
        MenuIcon.writePreviews(to: args[idx + 1])
        print("previews written to \(args[idx + 1])")
        return
    }

    // CLI hook for the Finder/Dock icon: leetcode-toggle --app-icon <iconset dir>
    if let idx = args.firstIndex(of: "--app-icon"), idx + 1 < args.count {
        MenuIcon.writeAppIcon(to: args[idx + 1])
        print("iconset written to \(args[idx + 1])")
        return
    }

    // CLI health check: leetcode-toggle --check [username]
    // Prints the same snapshot the menu bar uses, then exits.
    if let idx = args.firstIndex(of: "--check") {
        let username = idx + 1 < args.count ? args[idx + 1]
            : UserDefaults.standard.string(forKey: "username") ?? ""
        guard !username.isEmpty else {
            print("No username given (pass one or set it in Settings).")
            exit(2)
        }
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            do {
                let snap = try await LeetCodeAPI.snapshot(username: username)
                print("username:        \(snap.username)")
                print("challenge:       \(snap.challenge.title) [\(snap.challenge.difficulty ?? "?")]")
                print("challenge url:   \(snap.challenge.url)")
                print("didSolveToday:   \(snap.didSolveToday)")
                print("streak:          \(snap.streakDays) days")
                print("solved:          \(snap.solvedCount) (\(snap.totalSubmissions) submissions)")
                print("active last 7d:  \(snap.activeDaysLastWeek)/7")
                print("recent ACs:      \(snap.recentACs.count) (newest: \(snap.recentACs.first?.title ?? "-"))")
                print("icon state:      \(snap.didSolveToday ? "green + ✓ (solved)" : "red (not solved yet)")")
                done.signal()
            } catch {
                print("FAILED: \(error.localizedDescription)")
                exit(1) // process exits; the semaphore wait below is moot
            }
        }
        done.wait()
        exit(0)
    }

    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)

    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
