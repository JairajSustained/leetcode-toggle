import SwiftUI

/// The right-click "Activity" window: streak, today's challenge,
/// a 26-week heatmap ("when you coded") and recent accepted problems.
struct ActivityView: View {
    let model: AppModel

    var body: some View {
        Group {
            switch model.state {
            case .idle, .loading where model.snapshot == nil:
                center {
                    ProgressView("Loading your stats…")
                }
            case .failed(let message) where model.snapshot == nil:
                center {
                    VStack(spacing: 8) {
                        Text("Couldn't load your stats").font(.headline)
                        Text(message).font(.caption).foregroundStyle(.secondary)
                        Button("Retry") { model.refresh() }
                    }
                }
            default:
                if let snap = model.snapshot {
                    content(snap)
                } else {
                    center { ProgressView("Loading…") }
                }
            }
        }
        .frame(width: 460)
        .frame(minHeight: 420)
    }

    private func center(@ViewBuilder _ v: () -> some View) -> some View {
        VStack {
            Spacer()
            v()
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 320)
    }

    // MARK: - Content

    private func content(_ snap: Snapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(snap)
                challengeCard(snap)
                SectionCard(title: "When you coded — last \(26) weeks") {
                    VStack(alignment: .leading, spacing: 6) {
                        HeatmapView(calendar: snap.calendar)
                        HStack(spacing: 4) {
                            Text("less")
                            ForEach(0..<5, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(heatLevelColor(level: i))
                                    .frame(width: 10, height: 10)
                            }
                            Text("more")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
                SectionCard(title: "Recent problems") {
                    VStack(spacing: 0) {
                        let recent = Array(snap.recentACs.prefix(10))
                        if recent.isEmpty {
                            Text("No recent accepted solutions.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(recent.enumerated()), id: \.offset) { index, sub in
                                if index > 0 { Divider() }
                                RecentRow(submission: sub)
                            }
                        }
                    }
                }
                footer
            }
            .padding(16)
        }
    }

    private func header(_ snap: Snapshot) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: snap.avatarURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(snap.realName ?? snap.username)
                    .font(.headline)
                Text("@\(snap.username) · \(snap.solvedCount) solved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(snap.streakDays) \(snap.streakDays == 1 ? "day" : "days")")
                    .font(.headline)
                Text("streak 🔥")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func challengeCard(_ snap: Snapshot) -> some View {
        SectionCard(title: "Today's challenge") {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snap.challenge.title)
                        .font(.body.weight(.medium))
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        if let difficulty = snap.challenge.difficulty {
                            DifficultyChip(difficulty: difficulty)
                        }
                        StatusChip(done: snap.didSolveToday)
                    }
                }
                Spacer()
                Button {
                    model.openTodayChallenge()
                } label: {
                    Label("Open", systemImage: "arrow.up.right.square")
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            if case let .loaded(at) = model.state {
                Text("Updated \(at.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button("Refresh") { model.refresh() }
                .controlSize(.small)
        }
    }
}

// MARK: - Pieces

struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        )
    }
}

struct DifficultyChip: View {
    let difficulty: String

    private var color: Color {
        switch difficulty {
        case "Easy": .green
        case "Medium": .orange
        case "Hard": .red
        default: .gray
        }
    }

    var body: some View {
        Text(difficulty)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundStyle(color)
    }
}

struct StatusChip: View {
    let done: Bool

    var body: some View {
        Label(done ? "Solved today" : "Not solved yet",
              systemImage: done ? "checkmark.circle.fill" : "circle.dashed")
            .font(.caption2.weight(.medium))
            .foregroundStyle(done ? .green : .secondary)
    }
}

struct RecentRow: View {
    let submission: RecentSubmission

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
                .font(.caption)
            VStack(alignment: .leading, spacing: 1) {
                Text(submission.title)
                    .font(.callout)
                    .lineLimit(1)
                if let lang = submission.lang {
                    Text(lang)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(submission.timestamp, format: .relative(presentation: .named))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .onTapGesture { if let url = URL(string: submission.url) { NSWorkspace.shared.open(url) } }
        .help("Open \(submission.title)")
    }
}

// MARK: - Heatmap

func heatLevelColor(level: Int) -> Color {
    let green = Color(red: 0x6E / 255.0, green: 0xCC / 255.0, blue: 0x3A / 255.0)
    switch level {
    case 0: return Color(nsColor: .quaternaryLabelColor)
    case 1: return green.opacity(0.35)
    case 2: return green.opacity(0.55)
    case 3: return green.opacity(0.78)
    default: return green
    }
}

struct HeatmapView: View {
    let calendar: [Date: Int]
    var weeks: Int = 26

    private let cell: CGFloat = 12
    private let spacing: CGFloat = 3
    private let dayLabelWidth: CGFloat = 22

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 1 // Sunday
        return c
    }

    private var today: Date { .startOfTodayUTC }

    private var startOfWeek: Date {
        let today = self.today
        let weekday = cal.component(.weekday, from: today) // 1 = Sunday
        return cal.date(byAdding: .day, value: -(weekday - 1), to: today)!
    }

    /// Date for day-of-week d (0 = Sunday) in week w (0 = current, older = bigger).
    private func date(day: Int, week: Int) -> Date {
        cal.date(byAdding: .day, value: day - week * 7, to: startOfWeek)!
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            dayLabels
            VStack(alignment: .leading, spacing: 4) {
                monthLabels
                grid
            }
        }
        .fixedSize()
    }

    private var grid: some View {
        HStack(spacing: spacing) {
            ForEach((0..<weeks).reversed(), id: \.self) { w in
                VStack(spacing: spacing) {
                    ForEach(0..<7, id: \.self) { d in
                        let date = date(day: d, week: w)
                        let isFuture = date > today
                        let count = isFuture ? 0 : (calendar[date] ?? 0)
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(isFuture ? Color.clear : heatColor(level: level(for: count)))
                            .stroke(Color(nsColor: .separatorColor).opacity(isFuture ? 0.5 : 0), lineWidth: 0.5)
                            .frame(width: cell, height: cell)
                            .help(isFuture ? "" : label(for: date, count: count))
                    }
                }
            }
        }
    }

    private var monthLabels: some View {
        HStack(spacing: spacing) {
            ForEach((0..<weeks).reversed(), id: \.self) { w in
                Text(monthLabel(forWeek: w))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: cell, alignment: .leading)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .frame(height: 12, alignment: .bottomLeading)
    }

    /// Month name for the column where a month starts, else empty.
    private func monthLabel(forWeek w: Int) -> String {
        for d in 0..<7 {
            let date = date(day: d, week: w)
            if date > today { break }
            if date == cal.date(from: cal.dateComponents([.year, .month], from: date)) {
                return date.formatted(.dateTime.month(.abbreviated))
            }
        }
        return ""
    }

    private var dayLabels: some View {
        VStack(alignment: .trailing, spacing: spacing) {
            ForEach(0..<7, id: \.self) { d in
                Text(d == 1 ? "Mon" : d == 3 ? "Wed" : d == 5 ? "Fri" : "")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: dayLabelWidth, height: cell, alignment: .trailing)
            }
        }
    }

    private func level(for count: Int) -> Int {
        switch count {
        case 0: 0
        case 1...2: 1
        case 3...5: 2
        case 6...14: 3
        default: 4
        }
    }

    private func heatColor(level: Int) -> Color { heatLevelColor(level: level) }

    private func label(for date: Date, count: Int) -> String {
        let day = date.formatted(.dateTime.month(.abbreviated).day())
        return count == 1 ? "\(day) — 1 submission" : "\(day) — \(count) submissions"
    }
}
