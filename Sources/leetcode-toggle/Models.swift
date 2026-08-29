import Foundation

/// Today's daily coding challenge.
struct DailyChallenge: Sendable, Equatable {
    let title: String
    let titleSlug: String
    let difficulty: String?

    var url: String { "https://leetcode.com/problems/\(titleSlug)/" }
}

/// A recent accepted submission (for the "when you coded" view).
struct RecentSubmission: Sendable, Equatable {
    let title: String
    let titleSlug: String
    let timestamp: Date
    let lang: String?

    var url: String { "https://leetcode.com/problems/\(titleSlug)/" }
}

/// Aggregated snapshot of everything the UI needs.
struct Snapshot: Sendable {
    let username: String
    let challenge: DailyChallenge
    let streakDays: Int
    let totalActiveDays: Int
    let solvedCount: Int
    let totalSubmissions: Int
    /// Map of UTC midnight timestamp -> submission count for the current year.
    let calendar: [Date: Int]
    let recentACs: [RecentSubmission]
    let avatarURL: URL?
    let realName: String?
    let didSolveToday: Bool
    let fetchedAt: Date

    /// Dates (start of UTC day) with at least one submission in the last 7 days.
    var lastSevenDaysActivity: [(date: Date, count: Int)] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let today = cal.startOfDay(for: Date())
        var out: [(Date, Int)] = []
        for offset in (0...6).reversed() {
            guard let d = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            out.append((d, calendar[d] ?? 0))
        }
        return out
    }

    /// Number of days with activity in the last 7 days.
    var activeDaysLastWeek: Int { lastSevenDaysActivity.filter { $0.count > 0 }.count }
}

enum RefreshState: Equatable, Sendable {
    case idle
    case loading
    case loaded(Date)
    case failed(String)
}
