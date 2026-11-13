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
    enum Screen { case welcome, home, session, review }
    enum SessionKind { case sift, secondChance }

    var screen: Screen = .welcome
    var isLoading = false
    var errorMessage: String?
    /// Why the library could not be read, shown on the screen instead of a pop-up.
    var loadError: String?
    var toast: String?
    /// A newer release than the installed one, until it is dismissed.
    var availableUpdate: UpdateCheck.Release?

    var songs: [Song] = []
    var state: SavedState
    var filter: QueueFilter = .smart
    var sessionSize: Int { state.sessionSize }

    // Current session
    var sessionKind: SessionKind = .sift
    var chanceItems: [String: SecondChanceItem] = [:]
    var chanceChoices: [String: SecondChanceChoice] = [:]
    var queue: [Song] = []
    /// The artist whose songs this session goes through, when it is an artist session.
    var sessionArtist: String?
    /// The artist offered on the home screen.
    var spotlightArtist: String?
    var index = 0
    var history: [(song: Song, decision: Decision)] = []
    /// Set when you have deleted a few songs by one artist and Sift offers to go through the rest.
    var artistStop: ArtistStop?
    @ObservationIgnored private var offeredArtists: Set<String> = []
    @ObservationIgnored private var warmedArtists: Set<String> = []

    enum PauseKey { case swipe, artist, chance }

    /// A session you left part-way through, so Home can offer to pick it up again.
    struct PausedSession {
        let kind: SessionKind
        let artist: String?
        let queue: [Song]
        let index: Int
        let history: [(song: Song, decision: Decision)]
        let chanceItems: [String: SecondChanceItem]
        let chanceChoices: [String: SecondChanceChoice]
        let offeredArtists: Set<String>

        var left: Int { queue.count - index }
        func count(of decision: Decision) -> Int { history.filter { $0.decision == decision }.count }
    }

    /// One unfinished session per kind: the main session, an artist session and a Second Chance round.
    var paused: [PauseKey: PausedSession] = [:]

    struct ArtistStop: Equatable {
        let artist: String
        let deleted: Int
        let remaining: Int
    }

    // Clip playback
    var clipsEnabled: Bool { state.clipsEnabled }
    var clipStartedAt: Date?
    /// True while Music is loading or downloading the song, before the clip actually starts.
    var clipLoading = false
    /// True when Music could not play the song at all.
    var clipUnplayable = false
    /// True when the clip is Apple's short preview, false when it plays from the song in Music.
    var clipIsPreview = false
    var clipLength: Double { state.clipSeconds }

    let secondChanceWait: TimeInterval = 21 * 86_400

    private let music = MusicLibrary()
    private let store = StateStore()
    @ObservationIgnored private var clipTask: Task<Void, Never>?
    /// Observed, so a cover that arrives later shows up in views that are already on screen, like Up next.
    private var artworkCache: [String: NSImage] = [:]
    @ObservationIgnored private var artworkMisses: Set<String> = []
    @ObservationIgnored private var artworkPrefetch: Task<Void, Never>?
    @ObservationIgnored private let clipPlayer = ClipPlayer()
    @ObservationIgnored private var previewPrefetch: Task<Void, Never>?
    /// True while Music might still be playing, so the first preview pauses it.
    @ObservationIgnored private var musicMayBePlaying = true
    @ObservationIgnored private var artistImageCache: [String: NSImage] = [:]
    @ObservationIgnored private var artistImageMisses: Set<String> = []

    init() {
        state = StateStore().load()
        applyAppearance()
        Previews.trim()
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
        await checkForUpdate()
    }

    // MARK: Progress

    static func dayKey(_ date: Date = Date()) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private func bumpSwiped(by amount: Int) {
        let key = Self.dayKey()
        state.swipedByDay[key] = max(0, (state.swipedByDay[key] ?? 0) + amount)
    }

    /// Days in a row with at least one swipe. It stays alive through today until midnight tomorrow.
    var streakDays: Int {
        let calendar = Calendar.current
        var day = Date()
        if (state.swipedByDay[Self.dayKey(day)] ?? 0) == 0 {
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        var count = 0
        while (state.swipedByDay[Self.dayKey(day)] ?? 0) > 0 {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return count
    }

    private func lastSevenDays<T: Numeric>(_ values: [String: T]) -> T {
        let calendar = Calendar.current
        return (0..<7).reduce(0) { total, offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            return total + (values[Self.dayKey(day)] ?? 0)
        }
    }

    var weekSwiped: Int { lastSevenDays(state.swipedByDay) }
    var weekDeleted: Int { lastSevenDays(state.deletedByDay) }

    // MARK: Updates

    func checkForUpdate() async {
        guard state.checkUpdates, availableUpdate == nil else { return }
        guard let release = await UpdateCheck.newerRelease(), release.version != state.dismissedUpdate else { return }
        availableUpdate = release
    }

    func dismissUpdate() {
        state.dismissedUpdate = availableUpdate?.version
        availableUpdate = nil
        save()
    }

    func setCheckUpdates(_ value: Bool) {
        state.checkUpdates = value
        if !value { availableUpdate = nil }
        save()
        if value { Task { await checkForUpdate() } }
    }

    // MARK: Sound

    func setSounds(_ value: Bool) { state.soundsEnabled = value; save() }

    func feedback(_ cue: Feedback.Cue) {
        Feedback.play(cue, sounds: state.soundsEnabled)
    }

    func connect() async {
        isLoading = true
        defer { isLoading = false }
        do {
            songs = try await music.loadSongs()
            loadError = nil
            state.hasConnected = true
            pruneState()
            save()
            ensureSpotlight()
            if screen == .welcome { screen = .home }
        } catch {
            loadError = MusicLibrary.friendlyMessage(for: error)
            feedback(.error)
        }
    }

    /// True when the load failed because macOS has not allowed Sift to control Music.
    var loadErrorIsPermission: Bool { loadError?.contains("Automation") == true }

    /// Forgets songs that are no longer in the library, e.g. deleted on another device.
    private func pruneState() {
        let ids = Set(songs.map(\.id))
        state.kept = state.kept.filter { ids.contains($0.key) }
        state.secondChance = state.secondChance.filter { ids.contains($0.key) }
        state.pendingDelete.removeAll { !ids.contains($0) }
    }

    /// Takes every song off the waiting-to-delete list without deleting or keeping it.
    func clearPending() {
        state.pendingDelete = []
        save()
        showToast("Cleared the list")
    }

    func setSwapDirections(_ value: Bool) {
        state.swapDirections = value
        save()
    }

    func setClipSeconds(_ value: Double) {
        state.clipSeconds = value
        save()
    }

    func setAppearance(_ value: String) {
        state.appearance = value
        save()
        applyAppearance()
    }

    /// Sets the look of the whole app. SwiftUI's preferredColorScheme(nil) does not return to
    /// the Mac's setting once light or dark was picked, so the app's appearance is set directly instead.
    private func applyAppearance() {
        switch state.appearance {
        case "light": NSApplication.shared.appearance = NSAppearance(named: .aqua)
        case "dark": NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        default: NSApplication.shared.appearance = nil
        }
    }

    func setSessionSize(_ value: Int) {
        state.sessionSize = value
        save()
    }

    /// The name of a decision on the current screen. Second Chance rounds call it "Ask again".
    func label(for decision: Decision) -> String {
        sessionKind == .secondChance && decision == .secondChance ? "Ask again" : decision.label
    }

    // MARK: Session

    func startSession() {
        paused[.swipe] = nil
        sessionKind = .sift
        sessionArtist = nil
        queue = Scoring.queue(from: songs, state: state, filter: filter, limit: sessionSize)
        index = 0
        history = []
        artistStop = nil
        offeredArtists = []
        warmedArtists = []
        screen = .session
        playClipForCurrent()
        if queue.isEmpty { showToast("No songs match this filter right now") }
    }

    func endSession() {
        stopClip()
        pauseIfUnfinished()
        artistStop = nil
        sessionKind = .sift
        sessionArtist = nil
        screen = .home
        ensureSpotlight()
    }

    private var currentPauseKey: PauseKey {
        sessionKind == .secondChance ? .chance : sessionArtist != nil ? .artist : .swipe
    }

    /// Keeps the session when you leave it with songs still to go.
    private func pauseIfUnfinished() {
        guard screen == .session, index > 0, index < queue.count else { return }
        paused[currentPauseKey] = PausedSession(
            kind: sessionKind, artist: sessionArtist, queue: queue, index: index, history: history,
            chanceItems: chanceItems, chanceChoices: chanceChoices, offeredArtists: offeredArtists)
    }

    func resume(_ key: PauseKey) {
        guard let saved = paused[key] else { return }
        paused[key] = nil
        // Songs deleted in the meantime are dropped from what is left.
        let ids = Set(songs.map(\.id))
        let ahead = saved.queue[saved.index...].filter { ids.contains($0.id) }
        sessionKind = saved.kind
        sessionArtist = saved.artist
        queue = Array(saved.queue[..<saved.index]) + ahead
        index = saved.index
        history = saved.history
        chanceItems = saved.chanceItems
        chanceChoices = saved.chanceChoices
        offeredArtists = saved.offeredArtists
        artistStop = nil
        screen = .session
        playClipForCurrent()
    }

    func discardPaused(_ key: PauseKey) { paused[key] = nil }

    /// True when the review screen was opened from a session, so its back button returns there instead of Home.
    private(set) var reviewReturnsToSession = false

    /// Opens the review screen, from Home or the middle of a session. A session is kept, so you can go back to it.
    func openReview() {
        reviewReturnsToSession = screen == .session
        stopClip()
        pauseIfUnfinished()
        artistStop = nil
        screen = .review
    }

    /// Leaves the review screen for wherever it was opened from.
    func closeReview() {
        guard reviewReturnsToSession else { screen = .home; return }
        reviewReturnsToSession = false
        if paused[currentPauseKey] != nil {
            resume(currentPauseKey)
        } else {
            screen = .session
            playClipForCurrent()
        }
    }

    // MARK: Artist spotlight

    /// Songs by an artist that are still up for a decision, most likely clutter first.
    func songs(by artist: String) -> [Song] {
        let key = Scoring.artistKey(artist)
        let now = Date()
        return songs
            .filter { Scoring.artistKey($0.artist) == key && Scoring.isEligible($0, state: state, now: now) }
            .sorted { Scoring.clutterScore($0, now: now) > Scoring.clutterScore($1, now: now) }
    }

    var spotlightSongs: [Song] { spotlightArtist.map(songs(by:)) ?? [] }

    /// Keeps the current artist while they still have songs to go through, and picks a new one otherwise.
    func ensureSpotlight() {
        if let artist = spotlightArtist, songs(by: artist).count >= 2 { return }
        pickSpotlight()
    }

    /// Picks one of the least-played artists at random, avoiding the one already shown.
    func pickSpotlight() {
        let names = Scoring.spotlightCandidates(from: songs, state: state)
        spotlightArtist = names.filter { $0 != spotlightArtist }.randomElement() ?? names.first
    }

    /// The artist's photo, or nil when none could be found.
    func artistImage(for artist: String) async -> NSImage? {
        let key = Scoring.artistKey(artist)
        if let cached = artistImageCache[key] { return cached }
        if artistImageMisses.contains(key) { return nil }
        guard let image = await ArtistImages.fetch(artist) else {
            artistImageMisses.insert(key)
            return nil
        }
        artistImageCache[key] = image
        return image
    }

    func startArtistSession() {
        guard let artist = spotlightArtist else { return }
        let list = Array(songs(by: artist).prefix(60))
        guard !list.isEmpty else { pickSpotlight(); return }
        paused[.artist] = nil
        sessionKind = .sift
        sessionArtist = artist
        queue = list
        index = 0
        history = []
        artistStop = nil
        screen = .session
        playClipForCurrent()
    }

    /// Moves past the current song without deciding anything. It can come up again in a later session.
    func skipCurrent() {
        guard current != nil else { return }
        index += 1
        playClipForCurrent()
    }

    func decide(_ decision: Decision) {
        guard let song = current else { return }
        if sessionKind == .secondChance {
            switch decision {
            case .delete: chanceChoices[song.id] = .delete
            case .keep: chanceChoices[song.id] = .keep
            case .secondChance: chanceChoices[song.id] = .askAgain
            }
            history.append((song, decision))
            index += 1
            bumpSwiped(by: 1)
            save()
            feedback(.decision(decision))
            if current == nil { feedback(.done) }
            playClipForCurrent()
            return
        }
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
        bumpSwiped(by: 1)
        save()
        feedback(.decision(decision))
        if decision == .delete { warmArtist(after: song) }
        if decision == .delete, let stop = artistStopOffer(after: song) {
            artistStop = stop
            stopClip()
            return
        }
        if current == nil { feedback(.done) }
        playClipForCurrent()
    }

    /// After the second deletion by one artist, starts loading their first songs, so that if the third deletion
    /// brings up the artist stop, going through them starts without a wait.
    private func warmArtist(after song: Song) {
        guard sessionArtist == nil, sessionKind == .sift else { return }
        let key = Scoring.artistKey(song.artist)
        guard !key.isEmpty, !warmedArtists.contains(key) else { return }
        let deleted = history.filter { $0.decision == .delete && Scoring.artistKey($0.song.artist) == key }.count
        guard deleted >= 2 else { return }
        warmedArtists.insert(key)
        let first = Array(songs(by: song.artist).prefix(Self.lookahead))
        Task {
            for song in first {
                _ = await Previews.file(for: song)
                _ = await artwork(for: song)
            }
        }
    }

    /// After the third deletion by one artist, offers to go through the rest of their songs.
    private func artistStopOffer(after song: Song) -> ArtistStop? {
        guard sessionArtist == nil, sessionKind == .sift else { return nil }
        let key = Scoring.artistKey(song.artist)
        guard !key.isEmpty, !offeredArtists.contains(key) else { return nil }
        let deleted = history.filter { $0.decision == .delete && Scoring.artistKey($0.song.artist) == key }.count
        guard deleted >= 3 else { return nil }
        let remaining = songs(by: song.artist).count
        guard remaining >= 2 else { return nil }
        offeredArtists.insert(key)
        return ArtistStop(artist: song.artist, deleted: deleted, remaining: remaining)
    }

    /// Takes up the offer: their songs come next, then the rest of this session carries on.
    func acceptArtistStop() {
        guard let stop = artistStop else { return }
        artistStop = nil
        let theirs = Array(songs(by: stop.artist).prefix(30))
        let ids = Set(theirs.map(\.id))
        let rest = queue[index...].filter { !ids.contains($0.id) }
        queue = Array(queue[..<index]) + theirs + rest
        showToast("Going through \(stop.artist)")
        playClipForCurrent()
    }

    func declineArtistStop() {
        artistStop = nil
        playClipForCurrent()
    }

    func undo() {
        guard artistStop == nil else { return }
        guard let last = history.popLast() else { return }
        let id = last.song.id
        bumpSwiped(by: -1)
        if sessionKind == .secondChance {
            chanceChoices[id] = nil
            save()
            index = queue.firstIndex { $0.id == id } ?? max(0, index - 1)
            playClipForCurrent()
            return
        }
        switch last.decision {
        case .delete:
            state.pendingDelete.removeAll { $0 == id }
        case .keep:
            state.kept[id] = nil
        case .secondChance:
            state.secondChance[id] = nil
            Task { await perform { try await self.music.removeFromPlaylist(ids: [id], named: MusicLibrary.secondChancePlaylist) } }
        }
        index = queue.firstIndex { $0.id == id } ?? max(0, index - 1)
        save()
        feedback(.undo)
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
    }

    // MARK: Clips

    func playClipForCurrent() {
        if let song = current { playClip(for: song) } else { stopClip() }
    }

    func playClip(for song: Song) {
        clipTask?.cancel()
        clipPlayer.stop()
        clipStartedAt = nil
        clipUnplayable = false
        clipLoading = clipsEnabled
        guard clipsEnabled else {
            // Without clips nothing else starts the cover fetch for the songs coming up.
            prefetchArtwork()
            return
        }
        prefetchPreviews()
        clipTask = Task {
            // Apple's preview first: it is a small file that is usually fetched already, so it starts at once.
            if let file = await Previews.file(for: song) {
                guard !Task.isCancelled else { return }
                if musicMayBePlaying {
                    musicMayBePlaying = false
                    Task { try? await music.pause() }
                }
                do {
                    try clipPlayer.play(file)
                    clipIsPreview = true
                    clipLoading = false
                    clipStartedAt = Date()
                    prefetchArtwork()
                    try await Task.sleep(for: .seconds(clipLength))
                    clipPlayer.stop()
                    clipStartedAt = nil
                    return
                } catch is CancellationError {
                    return
                } catch {
                    // The file could not be played; fall back to the song in Music.
                }
            }
            guard !Task.isCancelled else { return }
            clipIsPreview = false
            musicMayBePlaying = true
            do {
                try await music.play(id: song.id, from: song.clipStart)
                try Task.checkCancellation()
                clipLoading = false
                clipStartedAt = Date()
                prefetchArtwork()
                try await Task.sleep(for: .seconds(clipLength))
                clipStartedAt = nil
                try await music.pause()
            } catch is CancellationError {
            } catch let error as OsaError where error.message.hasPrefix("Music couldn't play") {
                guard !Task.isCancelled else { return }
                clipLoading = false
                clipUnplayable = true
                feedback(.error)
                try? await music.pause()
            } catch {
                guard !Task.isCancelled else { return }
                clipLoading = false
                errorMessage = MusicLibrary.friendlyMessage(for: error)
                try? await music.pause()
            }
        }
    }

    func stopClip() {
        clipTask?.cancel()
        clipTask = nil
        clipPlayer.stop()
        clipStartedAt = nil
        clipLoading = false
        clipUnplayable = false
        if musicMayBePlaying { Task { try? await music.pause() } }
    }

    func setClipsEnabled(_ enabled: Bool) {
        state.clipsEnabled = enabled
        save()
        if !enabled { stopClip() } else if screen == .session { playClipForCurrent() }
    }

    func cachedArtwork(for song: Song) -> NSImage? { artworkCache[song.id] }

    private static let lookahead = 6

    /// Songs that come after the current one.
    private var upcoming: [Song] { Array(queue.dropFirst(index + 1).prefix(Self.lookahead)) }

    /// Fetches the previews of songs that will probably come up soon, such as the first songs of the next session.
    /// They are small files in the caches folder. Nothing is downloaded into the Music library.
    func warm(_ songs: [Song]) {
        Task { for song in songs { _ = await artwork(for: song) } }
        guard clipsEnabled else { return }
        Task { for song in songs { _ = await Previews.file(for: song) } }
    }

    /// Fetches the previews for the next few songs while the current clip plays, so they start at once.
    private func prefetchPreviews() {
        previewPrefetch?.cancel()
        let next = upcoming
        previewPrefetch = Task {
            for song in next {
                if Task.isCancelled { return }
                _ = await Previews.file(for: song)
            }
        }
    }

    /// Loads covers for the next few songs while the current clip plays, so they are ready when their turn comes.
    private func prefetchArtwork() {
        artworkPrefetch?.cancel()
        let next = upcoming
        artworkPrefetch = Task {
            for song in next {
                if Task.isCancelled { return }
                _ = await artwork(for: song)
            }
        }
    }

    func artwork(for song: Song) async -> NSImage? {
        if let cached = artworkCache[song.id] { return cached }
        if artworkMisses.contains(song.id) { return nil }
        var image: NSImage?
        var asked = false
        do {
            if let url = try await music.artworkFile(id: song.id), let data = try? Data(contentsOf: url) { image = NSImage(data: data) }
            asked = true
        } catch {}
        // Many cloud songs have no artwork in Music. Look it up online instead.
        if image == nil { image = await CoverLookup.fetch(song) }
        guard let image else {
            // A failed ask of Music may work later, so only remember a definite "none".
            if asked { artworkMisses.insert(song.id) }
            return nil
        }
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
            state.removedBytes += toDelete.reduce(0) { $0 + $1.diskBytes }
            state.removedSeconds += toDelete.reduce(0) { $0 + $1.duration }
            state.deletedByDay[Self.dayKey(), default: 0] += deleted
            save()
            showToast(deleted == 1 ? "Deleted 1 song" : "Deleted \(deleted) songs")
            return true
        } catch {
            errorMessage = MusicLibrary.friendlyMessage(for: error)
            return false
        }
    }

    // MARK: Second Chance

    /// Starts a swipe-style round over the songs whose waiting time is up.
    /// Opens a round. By default only songs whose wait is over; `all` goes through every song in the playlist.
    func openSecondChance(all: Bool = false) async {
        await connect()
        let items = secondChanceRound(all: all)
        guard !items.isEmpty else {
            showToast(all ? "There are no songs in Second Chance yet" : "No Second Chance songs are due yet")
            return
        }
        paused[.chance] = nil
        sessionKind = .secondChance
        sessionArtist = nil
        chanceItems = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        chanceChoices = [:]
        queue = items.map(\.song)
        index = 0
        history = []
        screen = .session
        playClipForCurrent()
    }

    /// How many plays a Second Chance song got since it was added to the playlist.
    func chanceInfo(for song: Song) -> (playsSince: Int, skipsSince: Int, added: Date?)? {
        guard sessionKind == .secondChance, let item = chanceItems[song.id] else { return nil }
        return (item.playsSince, item.skipsSince, state.secondChance[song.id]?.added)
    }

    func finishSecondChanceRound() async {
        let items = queue.compactMap { song -> SecondChanceItem? in
            guard var item = chanceItems[song.id] else { return nil }
            item.choice = chanceChoices[song.id] ?? .askAgain
            return item
        }
        await applySecondChance(items)
    }

    /// Songs whose waiting time is up, or all of them, with a suggested choice for each.
    func secondChanceRound(all: Bool = false) -> [SecondChanceItem] {
        let byID = songsByID
        let now = Date()
        return state.secondChance
            .filter { all || now.timeIntervalSince($0.value.added) >= secondChanceWait }
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
        sessionKind = .sift
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
