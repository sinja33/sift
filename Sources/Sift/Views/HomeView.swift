import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showingSettings = false

    /// False until the first read of the library is done.
    private var loaded: Bool { !(model.isLoading && model.songs.isEmpty) }

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header

                if let update = model.availableUpdate { updateBanner(update).transition(.opacity.combined(with: .move(edge: .top))) }

                if !(loaded && model.songs.isEmpty) {
                HStack(spacing: 36) {
                    HealthRing(value: model.healthScore, loading: model.isLoading && model.songs.isEmpty)
                    VStack(alignment: .leading, spacing: 14) {
                        Text("of your library played in the last 12 months")
                            .foregroundStyle(Theme.muted)
                        HStack(spacing: 36) {
                            StatView(value: model.songs.count.formatted(), label: "songs", size: 24)
                            StatView(value: model.neverPlayedCount.formatted(), label: "never played", size: 24)
                            StatView(value: model.state.removedCount.formatted(), label: "removed so far", size: 24)
                        }
                        .redacted(reason: loaded ? [] : .placeholder)
                        .shimmer(!loaded)
                        .animation(.smooth(duration: 0.4), value: loaded)
                    }
                }
                }

                if loaded && model.songs.isEmpty {
                    emptyOrError.reveal()
                } else if loaded {
                    // The three panels arrive together, one after the other.
                    // A second panel opens next to the session panel while songs wait to be deleted.
                    HStack(alignment: .top, spacing: 16) {
                        swipePanel
                        if !model.pendingDeleteSongs.isEmpty { deletePanel.transition(.opacity.combined(with: .scale(scale: 0.96))) }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(.smooth(duration: 0.4), value: model.state.pendingDelete.isEmpty)
                    .reveal(delay: 0.05)

                    HStack(alignment: .top, spacing: 16) {
                        spotlightPanel
                        chancePanel
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .reveal(delay: 0.15)
                } else {
                    SkeletonPanel(height: 130)
                    HStack(alignment: .top, spacing: 16) {
                        SkeletonPanel(height: 170)
                        SkeletonPanel(height: 170)
                    }
                }
            }
            .padding(44)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
            .animation(.smooth(duration: 0.35), value: model.availableUpdate)
        }
        .onAppear { model.ensureSpotlight() }
    }

    private func updateBanner(_ release: UpdateCheck.Release) -> some View {
        HStack(spacing: 14) {
            Mascot(mood: .wow, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Sift \(release.version) is out").font(.headline)
                Text(UpdateCheck.installed.map { "You have \($0). The new version is a free download." } ?? "The new version is a free download.")
                    .font(.callout).foregroundStyle(Theme.muted)
            }
            Spacer()
            Button("Later") { model.dismissUpdate() }.buttonStyle(.secondary)
            Button("Download") { NSWorkspace.shared.open(release.url) }.buttonStyle(.primary)
        }
        .panel(padding: 16)
    }

    /// Shown instead of the panels when the library could not be read, or has no songs in it.
    @ViewBuilder private var emptyOrError: some View {
        if let error = model.loadError {
            EmptyState(mood: .oops, title: model.loadErrorIsPermission ? "Sift can't reach Music yet" : "Couldn't read your library", message: error) {
                if model.loadErrorIsPermission {
                    Button("Open Automation settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
                    }.buttonStyle(.secondary)
                }
                Button("Try again") { Task { await model.connect() } }.buttonStyle(.primary)
            }
            .panel(padding: 20)
        } else {
            EmptyState(mood: .sleepy, title: "Your library is empty", message: "There are no songs in Music yet. Add some, then come back and refresh.") {
                Button("Open Music") { NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Music.app")) }.buttonStyle(.secondary)
                Button("Refresh") { Task { await model.connect() } }.buttonStyle(.primary)
            }
            .panel(padding: 20)
        }
    }

    @ViewBuilder private var spotlightPanel: some View {
        let songs = model.spotlightSongs
        if let artist = model.spotlightArtist, !songs.isEmpty {
            let never = songs.filter { $0.playCount == 0 }.count
            let titles = songs.prefix(3).map(\.title).joined(separator: ", ")
            FeaturePanel(
                label: "ARTIST SPOTLIGHT",
                title: artist,
                detail: "\(songs.count) songs · \(never) never played",
                description: songs.count > 3 ? "Starting with \(titles) and \(songs.count - 3) more." : "Starting with \(titles).",
                visual: { ArtistIcon() },
                buttons: {
                    Button("Go through their songs") { model.startArtistSession() }.buttonStyle(.primary)
                    Button { model.pickSpotlight() } label: { Label("Pick another artist", systemImage: "shuffle") }
                        .buttonStyle(.secondary)
                })
        }
    }

    private var swipePanel: some View {
        @Bindable var model = model
        let blurb: String
        switch model.filter {
        case .smart: blurb = "Songs you rarely play come first: never played, long untouched and often skipped. New songs and ones you recently kept are left out."
        case .neverPlayed: blurb = "Only songs you have never played, so you can decide whether they were ever worth keeping."
        case .oftenSkipped: blurb = "Songs you tend to skip when they come on. A quick way to find the ones you've already moved past."
        }
        return FeaturePanel(
            label: "SWIPE SESSION",
            title: "Clean up \(model.sessionSize) songs",
            detail: "\(model.neverPlayedCount.formatted()) never played · about 3 minutes",
            description: blurb,
            visual: { SwipeIcon() },
            buttons: {
                Button("Start session") { model.startSession() }
                    .buttonStyle(.primary)
                    .disabled(model.songs.isEmpty)
                Menu {
                    ForEach(QueueFilter.allCases) { option in
                        Button { model.filter = option } label: {
                            if option == model.filter { Label(option.rawValue, systemImage: "checkmark") } else { Text(option.rawValue) }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(model.filter.rawValue)
                        Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Theme.surface2, in: Capsule())
                    .contentShape(Capsule())
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .pointerCursor()
            })
    }

    private var deletePanel: some View {
        let songs = model.pendingDeleteSongs
        let artists = Set(songs.map { Scoring.artistKey($0.artist) }).count
        return FeaturePanel(
            label: "READY TO DELETE",
            title: songs.count == 1 ? "1 song marked" : "\(songs.count) songs marked",
            detail: "\(Format.totalTime(songs)) · \(artists) \(artists == 1 ? "artist" : "artists")",
            description: "They stay in your library until you confirm. Look over the list first, and untick anything you want to keep.",
            visual: { DeleteIcon() },
            buttons: {
                Button("Review and delete") { model.screen = .review }.buttonStyle(.danger)
                Button("Clear list") { model.clearPending() }.buttonStyle(.secondary)
            })
    }

    private var chancePanel: some View {
        let due = model.secondChanceDueCount
        let total = model.state.secondChance.count
        let title = total == 0 ? "Nothing waiting yet" : due > 0 ? "Round ready" : "\(total) songs waiting"
        let detail: String
        if total == 0 {
            detail = "Swipe up on a song to add it"
        } else if due > 0 {
            detail = "\(due) due now · \(total) in the playlist"
        } else if let days = daysUntilNextRound {
            detail = days <= 1 ? "Next round opens tomorrow" : "Next round opens in \(days) days"
        } else {
            detail = "\(total) in the playlist"
        }
        return FeaturePanel(
            label: "SECOND CHANCE",
            title: title,
            detail: detail,
            description: chanceText(due: due, total: total),
            visual: { SecondChanceIcon() },
            buttons: {
                if total == 0 {
                    Button("Start a session") { model.startSession() }
                        .buttonStyle(.secondary)
                        .disabled(model.songs.isEmpty)
                } else {
                    if due > 0 {
                        Button("Review round") { Task { await model.openSecondChance() } }
                            .buttonStyle(.primary)
                    }
                    if due < total {
                        Button(due > 0 ? "Go through all \(total)" : "Go through them now") { Task { await model.openSecondChance(all: true) } }
                            .buttonStyle(due > 0 ? .secondary : .primary)
                    }
                }
            })
    }

    /// Whole days until the first Second Chance song's three weeks are up.
    private var daysUntilNextRound: Int? {
        let now = Date()
        let remaining = model.state.secondChance.values
            .map { model.secondChanceWait - now.timeIntervalSince($0.added) }
            .filter { $0 > 0 }
        guard let soonest = remaining.min() else { return nil }
        return Int((soonest / 86_400).rounded(.up))
    }

    private func chanceText(due: Int, total: Int) -> String {
        if total == 0 { return "Songs you send to Second Chance wait here. After 3 weeks you can see which ones you played." }
        if due > 0 { return "\(due) songs have waited 3 weeks in the Second Chance playlist. See which ones you played." }
        return "\(total) songs are waiting in the Second Chance playlist. A round opens after 3 weeks, but you can go through them any time."
    }

    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                LogoMark(size: 44, cardsOnly: true)
                Text("sift").font(.system(size: 30, weight: .black)).tracking(-0.5)
            }
            .padding(.leading, 8)
            Spacer()
            if model.isLoading { ProgressView().controlSize(.small) }
            Button("Refresh") { Task { await model.connect() } }
                .buttonStyle(.secondary)
                .disabled(model.isLoading)
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 40, height: 40)
                    .background(Theme.surface2, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .pointerCursor()
            .help("Settings")
            .popover(isPresented: $showingSettings, arrowEdge: .bottom) { SettingsView() }
        }
    }
}

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings").font(Theme.display(20)).padding(.bottom, 12)
            row("Appearance", "Follow your Mac, or pick one") {
                PillPicker(options: ["system", "light", "dark"], selection: Binding(
                    get: { model.state.appearance }, set: { model.setAppearance($0) })) { $0.capitalized }
                    .frame(width: 200)
            }
            Divider()
            row("Swap swipe directions", "Left keeps, right deletes") {
                Toggle("", isOn: Binding(get: { model.state.swapDirections }, set: { model.setSwapDirections($0) }))
                    .toggleStyle(.switch).labelsHidden().pointerCursor()
            }
            Divider()
            row("Play clips", "Hear a short clip on each card") {
                Toggle("", isOn: Binding(get: { model.clipsEnabled }, set: { model.setClipsEnabled($0) }))
                    .toggleStyle(.switch).labelsHidden().pointerCursor()
            }
            Divider()
            row("Sounds", "A soft sound on each swipe") {
                Toggle("", isOn: Binding(get: { model.state.soundsEnabled }, set: { model.setSounds($0) }))
                    .toggleStyle(.switch).labelsHidden().pointerCursor()
            }
            Divider()
            row("Clip length", "How long each clip plays") {
                PillPicker(options: [10, 15, 30], selection: Binding(
                    get: { Int(model.clipLength) }, set: { model.setClipSeconds(Double($0)) })) { "\($0)s" }
                    .frame(width: 150)
            }
            Divider()
            row("Songs per session", "About 3 minutes for 20") {
                PillPicker(options: [10, 20, 50], selection: Binding(
                    get: { model.sessionSize }, set: { model.setSessionSize($0) })) { "\($0)" }
                    .frame(width: 150)
            }
            Divider()
            row("Check for updates", "Asks GitHub for the newest version") {
                Toggle("", isOn: Binding(get: { model.state.checkUpdates }, set: { model.setCheckUpdates($0) }))
                    .toggleStyle(.switch).labelsHidden().pointerCursor()
            }
        }
        .padding(20)
        .frame(width: 400)
    }

    private func row<Control: View>(_ title: String, _ detail: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.semibold)
                Text(detail).font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 8)
            control()
        }
        .padding(.vertical, 12)
    }
}

/// A home panel: a small label, something big to look at, a title and detail beside it, a description and the buttons.
private struct FeaturePanel<Visual: View, Buttons: View>: View {
    let label: String
    let title: String
    let detail: String
    let description: String
    @ViewBuilder var visual: Visual
    @ViewBuilder var buttons: Buttons

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(spacing: 18) {
                visual
                VStack(alignment: .leading, spacing: 8) {
                    Text(label).font(Theme.mono(11)).tracking(1).foregroundStyle(Theme.muted)
                    Text(title).font(Theme.display(24)).lineLimit(1)
                    Text(detail).font(.callout).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
            }
            Text(description)
                .font(.callout).foregroundStyle(Theme.muted)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { buttons }
                VStack(alignment: .leading, spacing: 10) { buttons }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .panel(padding: 20)
    }
}
