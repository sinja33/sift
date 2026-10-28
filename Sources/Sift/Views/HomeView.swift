import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                HStack(spacing: 32) {
                    HealthRing(value: model.healthScore)
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
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Swipe session").font(.headline)
                        Text("\(model.sessionSize) songs, least played first. About 3 minutes.")
                            .font(.callout).foregroundStyle(Theme.muted)
                        Picker("Songs", selection: $model.filter) {
                            ForEach(QueueFilter.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        Button("Start session") { model.startSession() }
                            .buttonStyle(.primary)
                            .disabled(model.songs.isEmpty)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .panel()

                    VStack(alignment: .leading, spacing: 12) {
                        let due = model.secondChanceDueCount
                        Text(due > 0 ? "Second Chance round ready" : "Second Chance").font(.headline)
                        Text(due > 0
                             ? "\(due) songs have waited 3 weeks in the Second Chance playlist. See which ones you played."
                             : "\(model.state.secondChance.count) songs are waiting in the Second Chance playlist. A round opens 3 weeks after you add a song.")
                            .font(.callout).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        if due > 0 {
                            Button("Review round") { Task { await model.openSecondChance() } }
                                .buttonStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .panel()
                }

                Toggle("Swipe left to keep and right to delete", isOn: Binding(
                    get: { model.state.swapDirections },
                    set: { model.setSwapDirections($0) }))
                    .toggleStyle(.checkbox)
                    .foregroundStyle(Theme.muted)
            }
            .padding(32)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            LogoMark(size: 34)
            Text("Sift").font(Theme.display(26))
            Spacer()
            if model.isLoading { ProgressView().controlSize(.small) }
            Button("Refresh") { Task { await model.connect() } }
                .buttonStyle(.secondary)
                .disabled(model.isLoading)
        }
    }
}
