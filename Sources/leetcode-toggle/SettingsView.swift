import SwiftUI

@MainActor
struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    let model: AppModel

    @State private var testMessage: String?
    @State private var isTesting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section("Account") {
                    TextField("LeetCode username", text: $settings.username)
                        .autocorrectionDisabled()
                        .onSubmit { model.refresh() }
                    Text("Your public username (the part of your leetcode.com/… profile URL). LeetCode only needs it to read your public stats — no password or token required.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Behavior") {
                    Picker("Refresh every", selection: $settings.refreshMinutes) {
                        Text("1 minute").tag(1)
                        Text("5 minutes").tag(5)
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                    }
                    .pickerStyle(.menu)
                    .onChange(of: settings.refreshMinutes) { _ in model.startTimer() }

                    Toggle("Launch at login", isOn: $settings.launchAtLogin)
                    if let error = settings.lastLaunchAtLoginError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section("Connection") {
                    HStack(spacing: 10) {
                        Button(isTesting ? "Testing…" : "Test connection") { runTest() }
                            .disabled(isTesting || !settings.hasUsername)
                        if let testMessage {
                            Text(testMessage)
                                .font(.caption)
                                .foregroundStyle(testMessage.hasPrefix("✓") ? Color.secondary : Color.red)
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 400)
        .frame(minHeight: 340)
        .onAppear { model.refresh() }
    }

    private func runTest() {
        testMessage = nil
        isTesting = true
        let username = settings.username.trimmingCharacters(in: .whitespaces)
        Task {
            defer { isTesting = false }
            do {
                let stats = try await LeetCodeAPI.userStats(
                    username: username,
                    year: Calendar.current.component(.year, from: Date())
                )
                testMessage = "✓ Connected — \(stats.solved) problems solved"
                model.refresh()
            } catch {
                testMessage = error.localizedDescription
            }
        }
    }
}
