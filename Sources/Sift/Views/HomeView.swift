import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showingSettings = false
    /// The first songs the next session would show, for the cover mosaic on the session panel.
    @State private var previewSongs: [Song] = []
    /// Panels side by side stack their buttons together: when one row of buttons does not fit, both stack.
    @State private var stackTopButtons = false
    @State private var stackBigRowButtons = false
    @State private var stackStripButtons = false

    /// False until the first read of the library is done.
    private var loaded: Bool { !(model.isLoading && model.songs.isEmpty) }

    var body: some View {
        @Bindable var model = model
        // Like the swipe screen, the layout depends on the window size: from 1100 wide the second row grows into full panels.
        GeometryReader { geo in
        let roomy = geo.size.width >= 1100
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header

                if let update = model.availableUpdate { updateBanner(update).transition(.opacity.combined(with: .move(edge: .top))) }

                if !(loaded && model.songs.isEmpty) {
                    // Wide: the space saved sits at the far right. Narrow: it moves under the stats, so they keep one line each.
                    ViewThatFits(in: .horizontal) {
                        overview(compact: false)
                        overview(compact: true)
                    }
                }

                if loaded && model.songs.isEmpty {
                    emptyOrError.reveal()
                } else if loaded {
                    // The two main panels arrive together, then the quiet strips for anything that needs a look.
                    HStack(alignment: .top, spacing: 16) {
                        swipePanel
                        spotlightPanel
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .environment(\.stackPanelButtons, stackTopButtons)
                    .onPreferenceChange(PanelButtonsOverflow.self) { stackTopButtons = $0 }
                    .reveal(delay: 0.05)

                    // The page spaces sections 32 apart; the strips sit closer, like the gap between the two panels above.
                    Group { if roomy { bigRow } else { strips } }.padding(.top, -16).reveal(delay: 0.15)
                } else {
                    HStack(alignment: .top, spacing: 16) {
                        SkeletonPanel(height: 170)
                        SkeletonPanel(height: 170)
                    }
                }
            }
            .padding(44)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
            .environment(\.panelButtonIcons, roomy)
            .animation(.smooth(duration: 0.35), value: model.availableUpdate)
        }
        .onAppear { model.ensureSpotlight() }
        .task(id: "\(model.songs.count)-\(model.filter.rawValue)-\(model.state.pendingDelete.count)-\(model.state.kept.count)-\(model.state.secondChance.count)") {
            previewSongs = Scoring.queue(from: model.songs, state: model.state, filter: model.filter, limit: 8)
            // Get the first songs of the next session ready while Home is open, so starting it has little to wait for.
            model.warm(Array(previewSongs.prefix(5)))
            model.warm(Array(model.spotlightSongs.prefix(3)))
        }
        }
    }

    private func updateBanner(_ release: UpdateCheck.Release) -> some View {
        HStack(spacing: 14) {
            Mascot(mood: .wow, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Sift \(release.version) is out").font(.headline)
                Text(UpdateCheck.installed.map { "You have \($0). The new version is a free download." } ?? "The new version is a free download.")
                    .font(.system(size: 13)).foregroundStyle(Theme.muted)
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

    /// The ring with the library stats beside it.
    private func overview(compact: Bool) -> some View {
        HStack(spacing: compact ? 28 : 36) {
            HealthRing(value: model.healthScore, loading: model.isLoading && model.songs.isEmpty)
            VStack(alignment: .leading, spacing: 14) {
                Text("of your library played in the last 12 months")
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: compact ? 24 : 36) {
                    StatView(value: model.songs.count.formatted(), label: "songs", size: 24)
                    StatView(value: model.neverPlayedCount.formatted(), label: "never played", size: 24)
                    StatView(value: model.state.removedCount.formatted(), label: "removed so far", size: 24)
                }
                .redacted(reason: loaded ? [] : .placeholder)
                .shimmer(!loaded)
                .animation(.smooth(duration: 0.4), value: loaded)
                if compact && loaded { spaceSaved.transition(.opacity) }
            }
            if !compact && loaded {
                Spacer(minLength: 16)
                spaceSaved.fixedSize().transition(.opacity)
            }
        }
    }

    /// What cleaning up is for: the disk space freed by the songs you have deleted with Sift.
    private var spaceSaved: some View {
        let bytes = model.state.removedBytes
        let size = bytes == 0 ? "0 MB" : ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
        return HStack(spacing: 6) {
            Image(systemName: "arrow.down.to.line").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.brand)
            Text(size).font(Theme.mono(15)).fontWeight(.bold).contentTransition(.numericText())
            Text("saved").foregroundStyle(Theme.muted)
        }
        .font(.system(size: 13))
        .help("Disk space freed by songs you deleted with Sift")
    }

    @ViewBuilder private var spotlightPanel: some View {
        if let saved = model.paused[.artist], let artist = saved.artist {
            pickupPanel(saved, key: .artist, label: "PICK UP · ARTIST", title: artist, visual: { ArtistAvatar(artist: artist) }) {
                model.discardPaused(.artist)
                model.spotlightArtist = artist
                model.startArtistSession()
            }
        } else {
            spotlightIdle
        }
    }

    @ViewBuilder private var spotlightIdle: some View {
        let songs = model.spotlightSongs
        if let artist = model.spotlightArtist, !songs.isEmpty {
            let never = songs.filter { $0.playCount == 0 }.count
            let titles = songs.prefix(3).map(\.title).joined(separator: ", ")
            FeaturePanel(
                label: "ARTIST SPOTLIGHT",
                title: artist,
                detail: "\(songs.count) songs · \(never) never played",
                description: songs.count > 3 ? "Starting with \(titles) and \(songs.count - 3) more." : "Starting with \(titles).",
                visual: { ArtistAvatar(artist: artist) },
                buttons: {
                    Button { model.startArtistSession() } label: { PanelLabel("Go through their songs", icon: "play.fill") }.buttonStyle(.primary)
                    Button { model.pickSpotlight() } label: { PanelLabel("Pick another artist", icon: "shuffle") }
                        .buttonStyle(.secondary)
                })
        }
    }

    @ViewBuilder private var swipePanel: some View {
        if let saved = model.paused[.swipe] {
            pickupPanel(saved, key: .swipe, label: "PICK UP · SWIPE SESSION", title: "Back to your session",
                        visual: { CoverMosaic(songs: Array(saved.queue[saved.index...]), size: 72) { SwipeIcon() } }) {
                model.discardPaused(.swipe)
                model.startSession()
            }
        } else {
            startPanel
        }
    }

    /// An unfinished session, with a way to carry on or begin again.
    private func pickupPanel<Visual: View>(_ saved: AppModel.PausedSession, key: AppModel.PauseKey, label: String, title: String,
                                           @ViewBuilder visual: () -> Visual, startOver: @escaping () -> Void) -> some View {
        FeaturePanel(
            label: label,
            title: title,
            detail: "\(saved.left) of \(saved.queue.count) left",
            description: "So far: \(saved.count(of: .delete)) to delete, \(saved.count(of: .secondChance)) in Second Chance, \(saved.count(of: .keep)) kept.",
            visual: visual,
            buttons: {
                Button { model.resume(key) } label: { PanelLabel("Continue", icon: "play.fill") }.buttonStyle(.primary)
                Button(action: startOver) { PanelLabel("Start over", icon: "arrow.counterclockwise") }.buttonStyle(.secondary)
            })
    }

    private var startPanel: some View {
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
            visual: { CoverMosaic(songs: previewSongs) { SwipeIcon() } },
            buttons: {
                Button { model.startSession() } label: { PanelLabel("Start session", icon: "play.fill") }
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

    /// Songs waiting to be deleted and Second Chance songs show up here only when there is something to look at.
    /// Each keeps half the width, in line with the panels above, so a lone strip does not stretch.
    private var strips: some View {
        let pending = model.pendingDeleteSongs
        let due = model.secondChanceDueCount
        let total = model.state.secondChance.count
        let resumed = model.paused[.chance]
        let chanceShown = total > 0 || resumed != nil
        return HStack(alignment: .top, spacing: 16) {
            if !pending.isEmpty {
                QuietStrip(
                    title: pending.count == 1 ? "1 song marked for deletion" : "\(pending.count) songs marked for deletion",
                    detail: "They stay in your library until you confirm",
                    button: "Review",
                    visual: { CoverMosaic(songs: pending, size: 40) { DeleteIcon(size: 40) } },
                    action: { model.openReview() },
                    clearAction: { model.clearPending() })
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
            if chanceShown {
                QuietStrip(
                    title: resumed != nil ? "Second Chance round paused" : due > 0 ? "Second Chance round ready" : "\(total) songs in Second Chance",
                    detail: resumed.map { "\($0.left) of \($0.queue.count) left" } ?? chanceDetail(due: due, total: total),
                    button: resumed != nil ? "Continue" : due > 0 ? "Review round" : "Go through now",
                    visual: { CoverMosaic(songs: model.secondChanceRound(all: true).map(\.song), size: 40) { SecondChanceIcon(size: 40) } },
                    action: { if resumed != nil { model.resume(.chance) } else { Task { await model.openSecondChance(all: due == 0) } } })
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
            if pending.isEmpty != !chanceShown { GapTip(text: pending.isEmpty ? Self.deleteTip : Self.chanceTip, tall: true) }
        }
        // Both strips take the height of the taller one.
        .fixedSize(horizontal: false, vertical: true)
        .animation(.smooth(duration: 0.4), value: pending.isEmpty)
        .animation(.smooth(duration: 0.4), value: total)
        .environment(\.stackPanelButtons, stackStripButtons)
        .onPreferenceChange(PanelButtonsOverflow.self) { stackStripButtons = $0 }
    }

    /// Shown in the empty half when only one of the two sections has something in it.
    private static let deleteTip = "Songs you swipe away wait here until you confirm. Nothing is deleted before that."
    private static let chanceTip = "Swipe up on a song to give it a Second Chance instead of deleting it."

    /// The same two sections as full panels, for when there is room.
    private var bigRow: some View {
        let pending = model.pendingDeleteSongs
        let due = model.secondChanceDueCount
        let total = model.state.secondChance.count
        let resumed = model.paused[.chance]
        let chanceShown = total > 0 || resumed != nil
        return HStack(alignment: .top, spacing: 16) {
            if !pending.isEmpty {
                FeaturePanel(
                    label: "READY TO DELETE",
                    title: pending.count == 1 ? "1 song marked" : "\(pending.count) songs marked",
                    detail: "\(Format.totalTime(pending)) · \(Set(pending.map { Scoring.artistKey($0.artist) }).count) artists",
                    description: "They stay in your library until you confirm. Look over the list first, and untick anything you want to keep.",
                    visual: { CoverMosaic(songs: pending) { DeleteIcon() } },
                    buttons: {
                        Button { model.openReview() } label: { PanelLabel("Review and delete", icon: "trash") }.buttonStyle(.secondary)
                        Button { model.clearPending() } label: { PanelLabel("Clear list", icon: "xmark") }.buttonStyle(CapsuleButtonStyle(fill: .clear, text: Theme.muted))
                    })
            }
            if chanceShown {
                FeaturePanel(
                    label: "SECOND CHANCE",
                    title: resumed != nil ? "Round paused" : due > 0 ? "Round ready" : "\(total) songs waiting",
                    detail: resumed.map { "\($0.left) of \($0.queue.count) left" } ?? chanceDetail(due: due, total: total),
                    description: resumed != nil
                        ? "You went through \(resumed?.index ?? 0) so far. Pick up where you stopped."
                        : due > 0
                        ? "\(due) songs have waited 3 weeks in the Second Chance playlist. See which ones you played."
                        : "\(total) songs are waiting in the Second Chance playlist. A round opens after 3 weeks, but you can go through them any time.",
                    visual: { CoverMosaic(songs: model.secondChanceRound(all: true).map(\.song)) { SecondChanceIcon() } },
                    buttons: {
                        if resumed != nil {
                            Button { model.resume(.chance) } label: { PanelLabel("Continue", icon: "play.fill") }.buttonStyle(.primary)
                            Button { model.discardPaused(.chance) } label: { PanelLabel("Start over", icon: "arrow.counterclockwise") }.buttonStyle(.secondary)
                        } else if due > 0 {
                            Button { Task { await model.openSecondChance() } } label: { PanelLabel("Review round", icon: "play.fill") }.buttonStyle(.primary)
                        }
                        if resumed == nil && due < total {
                            Button { Task { await model.openSecondChance(all: true) } } label: { PanelLabel(due > 0 ? "Go through all \(total)" : "Go through them now", icon: "play.fill") }
                                .buttonStyle(CapsuleButtonStyle.panel(primary: due == 0))
                        }
                    })
            }
            if pending.isEmpty != !chanceShown { GapTip(text: pending.isEmpty ? Self.deleteTip : Self.chanceTip, tall: true) }
        }
        .fixedSize(horizontal: false, vertical: true)
        .environment(\.stackPanelButtons, stackBigRowButtons)
        .onPreferenceChange(PanelButtonsOverflow.self) { stackBigRowButtons = $0 }
    }

    private func chanceDetail(due: Int, total: Int) -> String {
        if due > 0 { return "\(due) due now · \(total) in the playlist" }
        if let days = daysUntilNextRound { return days <= 1 ? "Next round opens tomorrow" : "Next round opens in \(days) days" }
        return "\(total) in the playlist"
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
                Text(detail).font(.system(size: 12)).foregroundStyle(Theme.muted)
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
    @Environment(\.stackPanelButtons) private var stacked

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 18) {
                visual
                VStack(alignment: .leading, spacing: 8) {
                    Text(label).font(Theme.mono(12)).tracking(1).foregroundStyle(Theme.muted)
                    Text(title).font(Theme.display(24)).lineLimit(1)
                    Text(detail).font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
            }
            Text(description)
                .font(.system(size: 13)).foregroundStyle(Theme.muted)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Group {
                if stacked {
                    VStack(alignment: .leading, spacing: 10) { buttons }
                } else {
                    HStack(spacing: 10) { buttons }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Measures whether the buttons fit on one line here. The row decides for every panel in it.
            .background {
                GeometryReader { room in
                    HStack(spacing: 10) { buttons }
                        .fixedSize()
                        .hidden()
                        .background(GeometryReader { row in
                            Color.clear.preference(key: PanelButtonsOverflow.self, value: row.size.width > room.size.width + 0.5)
                        })
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .panel(padding: 20)
    }
}

/// A panel button's text, with an icon in front when the window is big enough for the full layout.
private struct PanelLabel: View {
    let title: String
    let icon: String
    @Environment(\.panelButtonIcons) private var showsIcon

    init(_ title: String, icon: String) {
        self.title = title
        self.icon = icon
    }

    var body: some View {
        if showsIcon { Label(title, systemImage: icon) } else { Text(title) }
    }
}

private struct PanelButtonIconsKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Set by Home on wide windows, where the panel buttons have room for icons.
    fileprivate var panelButtonIcons: Bool {
        get { self[PanelButtonIconsKey.self] }
        set { self[PanelButtonIconsKey.self] = newValue }
    }
}

/// True when any panel in a row has more buttons than fit on one line.
private struct PanelButtonsOverflow: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

private struct StackPanelButtonsKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Set by a row of panels so they all stack their buttons, or none do.
    fileprivate var stackPanelButtons: Bool {
        get { self[StackPanelButtonsKey.self] }
        set { self[StackPanelButtonsKey.self] = newValue }
    }
}

/// A one-line row for things that need a look but are not the main event. It looks like the big panels, just shorter.
private struct QuietStrip<Visual: View>: View {
    let title: String
    let detail: String
    let button: String
    @ViewBuilder var visual: Visual
    let action: () -> Void
    /// When set, a plain "Clear list" button after the main one empties the list.
    var clearAction: (() -> Void)? = nil

    @Environment(\.stackPanelButtons) private var stacked
    /// Below this the title would be cut too short, so the button moves under it.
    private static var minTextWidth: CGFloat { 150 }

    var body: some View {
        HStack(spacing: 14) {
            visual
            if stacked {
                // The buttons sit at the bottom, like in the panels above, so both strips line up.
                VStack(alignment: .leading, spacing: 8) {
                    texts
                    Spacer(minLength: 0)
                    actionButton
                }
                .frame(maxHeight: .infinity, alignment: .topLeading)
                Spacer(minLength: 0)
            } else {
                texts
                Spacer(minLength: 8)
                actionButton
            }
        }
        .background {
            // Measures whether the text and button fit side by side. The row decides for both strips.
            GeometryReader { room in
                // 40 is the strips' cover size; a stand-in avoids loading the covers twice.
                HStack(spacing: 14) { Color.clear.frame(width: 40, height: 1); Color.clear.frame(width: Self.minTextWidth, height: 1); actionButton }
                    .padding(.trailing, 8)
                    .fixedSize()
                    .hidden()
                    .background(GeometryReader { row in
                        Color.clear.preference(key: PanelButtonsOverflow.self, value: row.size.width > room.size.width + 0.5)
                    })
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line))
    }

    private var texts: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 15, weight: .semibold)).lineLimit(1)
            Text(detail).font(.system(size: 13)).foregroundStyle(Theme.muted).lineLimit(1)
        }
    }

    private var actionButton: some View {
        HStack(spacing: 8) {
            Button(button, action: action).buttonStyle(QuietButtonStyle()).lineLimit(1).fixedSize()
            if let clearAction {
                Button("Clear list", action: clearAction).buttonStyle(QuietButtonStyle(fill: .clear, text: Theme.muted)).lineLimit(1).fixedSize()
            }
        }
    }
}

/// The same grey as the secondary buttons in the big panels, just smaller.
private struct QuietButtonStyle: ButtonStyle {
    var fill: Color = Theme.surface2
    var text: Color = Theme.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .foregroundStyle(text)
            .background(fill, in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.smooth(duration: 0.15), value: configuration.isPressed)
            .contentShape(Capsule())
            .pointerCursor()
    }
}

/// A quiet dashed card that fills the empty half of the second row.
private struct GapTip: View {
    let text: String
    var tall = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb").font(.system(size: 18)).foregroundStyle(Theme.chance)
            Text(text).font(.system(size: 13)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: tall ? .infinity : nil, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
    }
}
