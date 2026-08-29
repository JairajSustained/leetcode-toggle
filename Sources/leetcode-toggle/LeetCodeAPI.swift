import Foundation

/// Minimal LeetCode GraphQL client. All queries used here are public
/// (they work without cookies); we just need the user's username.
enum LeetCodeAPI {

    static let endpoint = URL(string: "https://leetcode.com/graphql")!

    enum APIError: LocalizedError {
        case http(Int)
        case graphQL([String])
        case decoding(String)
        case transport(String)

        var errorDescription: String? {
            switch self {
            case .http(let code): return "LeetCode returned HTTP \(code)."
            case .graphQL(let msgs): return "LeetCode error: " + msgs.joined(separator: "; ")
            case .decoding(let d): return "Could not read LeetCode response: \(d)"
            case .transport(let t): return "Network problem: \(t)"
            }
        }
    }

    // MARK: - Response shapes

    private struct GraphQLError: Decodable { let message: String? }

    private struct ChallengeData: Decodable {
        let activeDailyCodingChallengeQuestion: ChallengeNode?
    }
    private struct ChallengeNode: Decodable {
        let question: Question
    }
    private struct Question: Decodable {
        let title: String
        let titleSlug: String
        let difficulty: String?
    }

    private struct StatsData: Decodable {
        let matchedUser: MatchedUser?
    }
    private struct MatchedUser: Decodable {
        let username: String
        let profile: Profile?
        let submitStatsGlobal: SubmitStats?
        let userCalendar: UserCalendar?
        let prevCalendar: UserCalendar?
    }
    private struct Profile: Decodable {
        let userAvatar: String?
        let realName: String?
    }
    private struct SubmitStats: Decodable {
        let acSubmissionNum: [ACNum]?
    }
    private struct ACNum: Decodable {
        let difficulty: String
        let count: Int
        let submissions: Int?
    }
    private struct UserCalendar: Decodable {
        let streak: Int?
        let totalActiveDays: Int?
        /// JSON *string* of { "unixDay": count }
        let submissionCalendar: String?
    }

    private struct SubmissionsData: Decodable {
        let recentAcSubmissionList: [SubmissionNode]?
    }
    private struct SubmissionNode: Decodable {
        let title: String?
        let titleSlug: String
        let timestamp: String?
        let lang: String?
    }

    // MARK: - Public API

    static func dailyChallenge() async throws -> DailyChallenge {
        let query = """
        { activeDailyCodingChallengeQuestion { question { title titleSlug difficulty } } }
        """
        let data: ChallengeData = try await post(query)
        guard let q = data.activeDailyCodingChallengeQuestion?.question else {
            throw APIError.graphQL(["no active daily challenge"])
        }
        return DailyChallenge(title: q.title, titleSlug: q.titleSlug, difficulty: q.difficulty)
    }

    /// Everything about the user in a single call.
    /// Fetches the current year's calendar plus the previous year's, so a
    /// 26-week heatmap can span a year boundary.
    static func userStats(username: String, year: Int) async throws -> (
        realName: String?, avatar: URL?, solved: Int, submissions: Int,
        streak: Int, totalActiveDays: Int, calendar: [Date: Int]
    ) {
        let query = """
        query userProfileStats($username: String!, $year: Int!, $prevYear: Int!) {
          matchedUser(username: $username) {
            username
            profile { userAvatar realName }
            submitStatsGlobal { acSubmissionNum { difficulty count submissions } }
            userCalendar(year: $year) {
              streak
              totalActiveDays
              submissionCalendar
            }
            prevCalendar: userCalendar(year: $prevYear) {
              submissionCalendar
            }
          }
        }
        """
        let data: StatsData = try await post(query, variables: [
            "username": username, "year": year, "prevYear": year - 1
        ])
        guard let user = data.matchedUser else {
            throw APIError.graphQL(["user \"\(username)\" not found"])
        }

        var solved = 0, totalSubs = 0
        if let nums = user.submitStatsGlobal?.acSubmissionNum {
            for n in nums where n.difficulty == "All" {
                solved = n.count
                totalSubs = n.submissions ?? 0
            }
        }

        var calendar: [Date: Int] = [:]
        for raw in [user.userCalendar?.submissionCalendar, user.prevCalendar?.submissionCalendar] {
            guard let raw,
                  let calData = raw.data(using: .utf8),
                  let pairs = try? JSONDecoder().decode([String: Int].self, from: calData) else { continue }
            for (key, count) in pairs {
                if let ts = Int(key) {
                    calendar[Date(timeIntervalSince1970: TimeInterval(ts))] = count
                }
            }
        }

        let avatar = user.profile?.userAvatar.flatMap(URL.init(string:))
        return (
            user.profile?.realName,
            avatar,
            solved,
            totalSubs,
            user.userCalendar?.streak ?? 0,
            user.userCalendar?.totalActiveDays ?? 0,
            calendar
        )
    }

    static func recentACSubmissions(username: String, limit: Int = 30) async throws -> [RecentSubmission] {
        let query = """
        query recentAC($username: String!, $limit: Int!) {
          recentAcSubmissionList(username: $username, limit: $limit) {
            title titleSlug timestamp lang
          }
        }
        """
        let data: SubmissionsData = try await post(query, variables: ["username": username, "limit": limit])
        let nodes = data.recentAcSubmissionList ?? []
        return nodes.compactMap { node in
            guard let ts = node.timestamp.flatMap(Int.init) else { return nil }
            return RecentSubmission(
                title: node.title ?? node.titleSlug,
                titleSlug: node.titleSlug,
                timestamp: Date(timeIntervalSince1970: TimeInterval(ts)),
                lang: node.lang
            )
        }
    }

    /// Build the full UI snapshot, deciding "did I do today's challenge".
    static func snapshot(username: String) async throws -> Snapshot {
        let year = Calendar.current.component(.year, from: Date())
        async let challenge = dailyChallenge()
        async let stats = userStats(username: username, year: year)
        async let recent = recentACSubmissions(username: username)
        do {
            let (c, s, r) = try await (challenge, stats, recent)
            // "Done" = an accepted submission of today's challenge on/after UTC midnight.
            let startOfTodayUTC = Date.startOfTodayUTC
            let didSolve = r.contains { $0.titleSlug == c.titleSlug && $0.timestamp >= startOfTodayUTC }
            return Snapshot(
                username: username,
                challenge: c,
                streakDays: s.streak,
                totalActiveDays: s.totalActiveDays,
                solvedCount: s.solved,
                totalSubmissions: s.submissions,
                calendar: s.calendar,
                recentACs: r,
                avatarURL: s.avatar,
                realName: s.realName,
                didSolveToday: didSolve,
                fetchedAt: Date()
            )
        } catch {
            throw error
        }
    }

    // MARK: - Transport

    private static func post<T: Decodable>(_ query: String, variables: [String: Any] = [:]) async throws -> T {
        var body: [String: Any] = ["query": query]
        if !variables.isEmpty { body["variables"] = variables }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("LeetCodeToggle/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 20

        let (responseData, response): (Data, URLResponse)
        do {
            (responseData, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw APIError.http(http.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw APIError.decoding("response is not a JSON object")
        }

        if let errs = json["errors"] as? [[String: Any]] {
            let messages = errs.compactMap { $0["message"] as? String }
            if !messages.isEmpty { throw APIError.graphQL(messages) }
        }
        guard let dataObj = json["data"] else {
            throw APIError.graphQL(["empty response"])
        }
        guard let payload = try? JSONSerialization.data(withJSONObject: dataObj) else {
            throw APIError.decoding("could not re-serialize data object")
        }

        do {
            return try JSONDecoder().decode(T.self, from: payload)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }
}

extension Date {
    /// Start of the current day in UTC (LeetCode's day boundary).
    static var startOfTodayUTC: Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.startOfDay(for: Date())
    }
}
