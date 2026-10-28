import AppKit
import SwiftUI

enum Decision: String, Codable {
    case delete, keep, secondChance

    var label: String {
        switch self {
        case .delete: "Delete"
        case .keep: "Keep"
        case .secondChance: "Second Chance"
        }
    }

    var symbol: String {
        switch self {
        case .delete: "xmark"
        case .keep: "heart.fill"
        case .secondChance: "clock"
        }
    }

    var tint: Color {
        switch self {
        case .delete: Theme.delete
        case .keep: Theme.keep
        case .secondChance: Theme.chance
        }
    }

    var soft: Color {
        switch self {
        case .delete: Theme.deleteSoft
        case .keep: Theme.keepSoft
        case .secondChance: Theme.chanceSoft
        }
    }
}

enum SecondChanceChoice: String, CaseIterable, Identifiable {
    case keep = "Keep"
    case delete = "Delete"
    case askAgain = "Ask again"
    var id: String { rawValue }
}

struct SecondChanceItem: Identifiable {
    let song: Song
    let playsSince: Int
    let skipsSince: Int
    var choice: SecondChanceChoice
    var id: String { song.id }
}

@MainActor
@Observable
final class AppModel {
    enum Screen { case welcome, home, session, review, secondChance }

    var screen: Screen = .welcome
    var isLoading = false
    var errorMessage: String?
    var toast: String?

    var songs: [Song] = []
    var state: SavedState
    var filter: QueueFilter = .smart
    let sessionSize = 20

    // Current session
    var queue: [Song] = []
    var index = 0
    var history: [(song: Song, decision: Decision)] = []

    // Clip playback
    var clipsEnabled = true
    var clipStartedAt: Date?
    let clipLength: Double = 15

    let secondChanceWait: TimeInterval = 21 * 86_400

    private let music = MusicLibrary()
    private let store = StateStore()
    @ObservationIgnored private var clipTask: Task<Void, Never>?
    @ObservationIgnored private var artworkCache: [String: NSImage] = [:]

    init() {
        state = StateStore().load()
    }

    // MARK: Library

    var current: Song? { index < queue.count ? queue[index] : nil }
    var next: Song? { index + 1 < queue.count ? queue[index + 1] : nil }

    var leftDecision: Decision { state.swapDirections ? .keep : .delete }
    var rightDecision: Decision { state.swapDirections ? .delete : .keep }

    var pendingDeleteSongs: [Song] {
        let byID = songsByID
        return state.pendingDelete.compactMap { byID[$0] }
    }

    var neverPlayedCount: Int { songs.filter { $0.playCount == 0 }.count }

    /// Share of the library played in the last 12 months.
    var healthScore: Double {
        guard !songs.isEmpty else { return 0 }
        let yearAgo = Date().addingTimeInterval(-365 * 86_400)
        let played = songs.filter { ($0.lastPlayed ?? .distantPast) > yearAgo }.count
        return Double(played) / Double(songs.count)
    }

    var secondChanceDueCount: Int {
        let now = Date()
        return state.secondChance.values.filter { now.timeIntervalSince($0.added) >= secondChanceWait }.count
    }

    private var songsByID: [String: Song] {
        Dictionary(songs.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func start() async {
        guard state.hasConnected else { return }
        screen = .home
        await connect()
    }

    func connect() async {
        isLoading = true
        defer { isLoading = false }
        do {
            songs = try await music.loadSongs()
            state.hasConnected = true
            pruneState()
            save()
            if screen == .welcome { screen = .home }
        } catch {
            errorMessage = MusicLibrary.friendlyMessage(for: error)
        }
    }

    /// Forgets songs that are no longer in the library, e.g. deleted on another device.
    private func pruneState() {
        let ids = Set(songs.map(\.id))
        state.kept = state.kept.filter { ids.contains($0.key) }
        state.secondChance = state.secondChance.filter { ids.contains($0.key) }
        state.pendingDelete.removeAll { !ids.contains($0) }
    }

    func setSwapDirections(_ value: Bool) {
        state.swapDirections = value
        save()
    }

    // MARK: Session

    func startSession() {
        queue = Scoring.queue(from: songs, state: state, filter: filter, limit: sessionSize)
        index = 0
        history = []
        screen = .session
        playClipForCurrent()
        if queue.isEmpty { showToast("No songs match this filter right now") }
    }

    func endSession() {
        stopClip()
        screen = .home
    }

    func decide(_ decision: Decision) {
        guard let song = current else { return }
        switch decision {
        case .delete:
            if !state.pendingDelete.contains(song.id) { state.pendingDelete.append(song.id) }
        case .keep:
            state.kept[song.id] = Date()
        case .secondChance:
            addToSecondChance(song, round: 1)
        }
        history.append((song, decision))
        index += 1
        save()
        playClipForCurrent()
    }

    func undo() {
        guard let last = history.popLast() else { return }
        let id = last.song.id
        switch last.decision {
        case .delete:
            state.pendingDelete.removeAll { $0 == id }
        case .keep:
            state.kept[id] = nil
        case .secondChance:
            state.secondChance[id] = nil
            Task { await perform { try await self.music.removeFromPlaylist(ids: [id], named: MusicLibrary.secondChancePlaylist) } }
        }
        index = max(0, index - 1)
        save()
        playClipForCurrent()
    }

    func count(of decision: Decision) -> Int {
        history.filter { $0.decision == decision }.count
    }

    private func addToSecondChance(_ song: Song, round: Int) {
        state.secondChance[song.id] = ChanceEntry(
            added: Date(), playsWhenAdded: song.playCount, skipsWhenAdded: song.skipCount, round: round)
        let id = song.id
        Task { await perform { try await self.music.addToPlaylist(ids: [id], named: MusicLibrary.secondChancePlaylist) } }
        showToast("Added to Second Chance")
    }

    // MARK: Clips

    func playClipForCurrent() {
        if let song = current { playClip(for: song) } else { stopClip() }
    }

    func playClip(for song: Song) {
        clipTask?.cancel()
        clipStartedAt = nil
        guard clipsEnabled else { return }
        clipTask = Task {
            do {
                try await music.play(id: song.id, from: song.clipStart)
                try Task.checkCancellation()
                clipStartedAt = Date()
                try await Task.sleep(for: .seconds(clipLength))
                clipStartedAt = nil
                try await music.pause()
            } catch is CancellationError {
            } catch {
                errorMessage = MusicLibrary.friendlyMessage(for: error)
            }
        }
    }

    func stopClip() {
        clipTask?.cancel()
        clipTask = nil
        clipStartedAt = nil
        Task { try? await music.pause() }
    }

    func setClipsEnabled(_ enabled: Bool) {
        clipsEnabled = enabled
        if enabled { playClipForCurrent() } else { stopClip() }
    }

    func artwork(for song: Song) async -> NSImage? {
        if let cached = artworkCache[song.id] { return cached }
        guard let url = try? await music.artworkFile(id: song.id),
              let data = try? Data(contentsOf: url),
              let image = NSImage(data: data) else { return nil }
        artworkCache[song.id] = image
        return image
    }

    // MARK: Review and delete

    /// Deletes the selected songs. Unselected ones count as kept.
    func confirmReview(selected: Set<String>, backup: Bool) async -> Bool {
        let toDelete = songs.filter { selected.contains($0.id) }
        do {
            if backup && !toDelete.isEmpty { try Backup.write(toDelete) }
            var deleted = 0
            if !toDelete.isEmpty { deleted = try await music.delete(ids: toDelete.map(\.id)) }
            let now = Date()
            for id in state.pendingDelete where !selected.contains(id) { state.kept[id] = now }
            state.pendingDelete = []
            songs.removeAll { selected.contains($0.id) }
            state.removedCount += deleted
            save()
            showToast(deleted == 1 ? "Deleted 1 song" : "Deleted \(deleted) songs")
            return true
        } catch {
            errorMessage = MusicLibrary.friendlyMessage(for: error)
            return false
        }
    }

    // MARK: Second Chance

    func openSecondChance() async {
        await connect()
        screen = .secondChance
    }

    /// Songs whose waiting time is up, with a suggested choice for each.
    func secondChanceRound() -> [SecondChanceItem] {
        let byID = songsByID
        let now = Date()
        return state.secondChance
            .filter { now.timeIntervalSince($0.value.added) >= secondChanceWait }
            .compactMap { pair -> SecondChanceItem? in
                let entry = pair.value
                guard let song = byID[pair.key] else { return nil }
                let plays = max(0, song.playCount - entry.playsWhenAdded)
                let skips = max(0, song.skipCount - entry.skipsWhenAdded)
                let choice: SecondChanceChoice
                if plays > 0 { choice = .keep }
                else if skips > 0 || entry.round >= 2 { choice = .delete }
                else { choice = .askAgain }
                return SecondChanceItem(song: song, playsSince: plays, skipsSince: skips, choice: choice)
            }
            .sorted { $0.song.title.localizedCaseInsensitiveCompare($1.song.title) == .orderedAscending }
    }

    func applySecondChance(_ items: [SecondChanceItem]) async {
        stopClip()
        let now = Date()
        var leaving: [String] = []
        for item in items {
            let id = item.song.id
            switch item.choice {
            case .keep:
                state.kept[id] = now
                state.secondChance[id] = nil
                leaving.append(id)
            case .delete:
                if !state.pendingDelete.contains(id) { state.pendingDelete.append(id) }
                state.secondChance[id] = nil
                leaving.append(id)
            case .askAgain:
                let round = (state.secondChance[id]?.round ?? 1) + 1
                state.secondChance[id] = ChanceEntry(
                    added: now, playsWhenAdded: item.song.playCount, skipsWhenAdded: item.song.skipCount, round: round)
            }
        }
        save()
        if !leaving.isEmpty {
            await perform { try await self.music.removeFromPlaylist(ids: leaving, named: MusicLibrary.secondChancePlaylist) }
        }
        screen = state.pendingDelete.isEmpty ? .home : .review
    }

    // MARK: Helpers

    func showToast(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if toast == message { toast = nil }
        }
    }

    private func perform(_ work: () async throws -> Void) async {
        do { try await work() } catch { errorMessage = MusicLibrary.friendlyMessage(for: error) }
    }

    private func save() {
        store.save(state)
    }
}
