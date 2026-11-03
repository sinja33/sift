import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showingSettings = false

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
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
                    }
                }

                if !model.state.pendingDelete.isEmpty {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(model.state.pendingDelete.count) songs marked for deletion").font(.headline)
                            Text("They stay in your library until you confirm.").font(.callout).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Button("Review and delete") { model.screen = .review }.buttonStyle(.danger)
                    }
                    .panel()
                }

                HStack(alignment: .top, spacing: 16) {
                    swipePanel
                    chancePanel
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(32)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
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
        return VStack(alignment: .leading, spacing: 12) {
            Text(due > 0 ? "Second Chance round ready" : "Second Chance").font(.headline)
            Text(due > 0
                 ? "\(due) songs have waited 3 weeks in the Second Chance playlist. See which ones you played."
                 : "\(model.state.secondChance.count) songs are waiting in the Second Chance playlist. A round opens 3 weeks after you add a song.")
                .font(.callout).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if due > 0 {
                Button("Review round") { Task { await model.openSecondChance() } }
                    .buttonStyle(.secondary)
            }
        }
        .frame(minWidth: 220, maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .panel(padding: 20)
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
