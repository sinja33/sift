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

                if loaded && !model.state.pendingDelete.isEmpty {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(model.state.pendingDelete.count) songs marked for deletion").font(.headline)
                            Text("They stay in your library until you confirm.").font(.callout).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Button("Review and delete") { model.screen = .review }.buttonStyle(.danger)
                    }
                    .panel()
                    .reveal()
                }

                if loaded {
                    // The three panels arrive together, one after the other.
                    HStack(alignment: .top, spacing: 16) {
                        swipePanel
                        chancePanel
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .reveal(delay: 0.05)

                    spotlightPanel.reveal(delay: 0.15)
                } else {
                    HStack(alignment: .top, spacing: 16) {
                        SkeletonPanel()
                        SkeletonPanel()
                    }
                    SkeletonPanel(height: 170)
                }
            }
            .padding(44)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .onAppear { model.ensureSpotlight() }
    }

    @ViewBuilder private var spotlightPanel: some View {
        let songs = model.spotlightSongs
        if let artist = model.spotlightArtist, !songs.isEmpty {
            let never = songs.filter { $0.playCount == 0 }.count
            let plays = songs.reduce(0) { $0 + $1.playCount }
            let titles = songs.prefix(3).map(\.title).joined(separator: ", ")
            VStack(alignment: .leading, spacing: 26) {
                HStack(spacing: 18) {
                    ArtistAvatar(artist: artist, gradient: avatarGradient(artist))
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ARTIST SPOTLIGHT").font(Theme.mono(11)).tracking(1).foregroundStyle(Theme.muted)
                        Text(artist).font(Theme.display(24)).lineLimit(1)
                        Text("\(songs.count) songs to go through · \(never) never played · \(plays) plays in total")
                            .font(.callout).foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 0)
                }
                Text(songs.count > 3 ? "Starting with \(titles) and \(songs.count - 3) more." : "Starting with \(titles).")
                    .font(.callout).foregroundStyle(Theme.muted).lineLimit(2)
                HStack(spacing: 10) {
                    Button("Go through their songs") { model.startArtistSession() }.buttonStyle(.primary)
                    Button { model.pickSpotlight() } label: { Label("Pick another artist", systemImage: "shuffle") }
                        .buttonStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .panel(padding: 20)
        }
    }

    private func avatarGradient(_ name: String) -> LinearGradient {
        let seed = name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFFFF }
        let hue = Double(seed % 360) / 360
        return LinearGradient(colors: [
            Color(hue: hue, saturation: 0.6, brightness: 0.95),
            Color(hue: (hue + 0.18).truncatingRemainder(dividingBy: 1), saturation: 0.8, brightness: 0.45)
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var swipePanel: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 12) {
            Text("Swipe session").font(.headline)
            Text("\(model.sessionSize) songs, least played first. About 3 minutes.")
                .font(.callout).foregroundStyle(Theme.muted)
            PillPicker(options: QueueFilter.allCases, selection: $model.filter) { $0.rawValue }
            Spacer(minLength: 0)
            Button("Start session") { model.startSession() }
                .buttonStyle(.primary)
                .disabled(model.songs.isEmpty)
        }
        .frame(minWidth: 220, maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .panel(padding: 20)
    }

    private var chancePanel: some View {
        let due = model.secondChanceDueCount
        let total = model.state.secondChance.count
        return VStack(alignment: .leading, spacing: 12) {
            Text(due > 0 ? "Second Chance round ready" : "Second Chance").font(.headline)
            Text(chanceText(due: due, total: total))
                .font(.callout).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if total > 0 {
                HStack(spacing: 10) {
                    if due > 0 {
                        Button("Review round") { Task { await model.openSecondChance() } }
                            .buttonStyle(.secondary)
                    }
                    if due < total {
                        Button(due > 0 ? "Go through all \(total)" : "Go through them now") { Task { await model.openSecondChance(all: true) } }
                            .buttonStyle(.secondary)
                    }
                }
            }
        }
        .frame(minWidth: 220, maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .panel(padding: 20)
    }

    private func chanceText(due: Int, total: Int) -> String {
        if total == 0 { return "Songs you send to Second Chance wait here. After 3 weeks you can see which ones you played." }
        if due > 0 { return "\(due) songs have waited 3 weeks in the Second Chance playlist. See which ones you played." }
        return "\(total) songs are waiting in the Second Chance playlist. A round opens after 3 weeks, but you can go through them any time."
    }

    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 2) {
                LogoMark(size: 44, cardsOnly: true)
                Text("sift").font(.system(size: 30, weight: .black)).tracking(-0.5)
            }
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

/// The artist's photo in a circle, with their initial on a colored tile until it loads or when none is found.
private struct ArtistAvatar: View {
    let artist: String
    let gradient: LinearGradient

    @Environment(AppModel.self) private var model
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                gradient
                Text(String(artist.prefix(1)).uppercased()).font(Theme.display(30)).foregroundStyle(.white)
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(Circle())
        .overlay(Circle().stroke(Theme.line))
        .task(id: artist) {
            image = nil
            image = await model.artistImage(for: artist)
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
