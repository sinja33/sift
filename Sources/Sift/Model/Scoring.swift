import Foundation

enum QueueFilter: String, CaseIterable, Identifiable {
    case smart = "Least played"
    case neverPlayed = "Never played"
    case oftenSkipped = "Often skipped"
    var id: String { rawValue }
}

enum Scoring {
    static let month: TimeInterval = 2_629_800
    static let newSongGrace: TimeInterval = 30 * 86_400
    static let keepHideTime: TimeInterval = 180 * 86_400

    /// Higher means more likely to be clutter.
    static func clutterScore(_ song: Song, now: Date) -> Double {
        let monthsInLibrary = song.dateAdded.map { now.timeIntervalSince($0) / month } ?? 12
        let monthsSincePlayed = song.lastPlayed.map { now.timeIntervalSince($0) / month } ?? monthsInLibrary
        var score = 0.0
        if song.playCount == 0 { score += 40 }
        score += min(monthsSincePlayed, 36) * 1.5
        score += Double(song.skipCount) * 4
        score -= Double(song.playCount) / max(monthsInLibrary, 1) * 20
        return score
    }

    /// Songs for the next session, most likely clutter first. Skips songs added in the
    /// last month, songs kept recently, and songs already waiting on a decision.
    static func queue(from songs: [Song], state: SavedState, filter: QueueFilter, limit: Int, now: Date = Date()) -> [Song] {
        let pending = Set(state.pendingDelete)
        let eligible = songs.filter { song in
            if pending.contains(song.id) || state.secondChance[song.id] != nil { return false }
            if let kept = state.kept[song.id], now.timeIntervalSince(kept) < keepHideTime { return false }
            if let added = song.dateAdded, now.timeIntervalSince(added) < newSongGrace { return false }
            switch filter {
            case .smart: return true
            case .neverPlayed: return song.playCount == 0
            case .oftenSkipped: return song.skipCount >= 2
            }
        }
        return eligible
            .map { (song: $0, score: clutterScore($0, now: now)) }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0.song }
    }
}

enum Format {
    static func age(_ date: Date?, now: Date = Date()) -> String {
        guard let date else { return "never" }
        let days = Int(now.timeIntervalSince(date) / 86_400)
        if days < 1 { return "today" }
        if days < 31 { return "\(days) d" }
        let months = days / 30
        if months < 24 { return "\(months) mo" }
        return "\(months / 12) yr"
    }

    static func monthYear(_ date: Date?) -> String {
        guard let date else { return "never" }
        return date.formatted(.dateTime.month(.abbreviated).year())
    }

    static func duration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func totalTime(_ songs: [Song]) -> String {
        let minutes = Int(songs.reduce(0) { $0 + $1.duration } / 60)
        return minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min of music" : "\(minutes) min of music"
    }
}

extension Song {
    /// Where the clip starts: about a third in, which usually lands near the chorus.
    var clipStart: Double {
        guard duration > 40 else { return 0 }
        return min(duration * 0.33, duration - 20)
    }
}
