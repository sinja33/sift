import SwiftUI

struct ReviewView: View {
    @Environment(AppModel.self) private var model
    @State private var selected: Set<String> = []
    @State private var backup = true
    @State private var confirming = false
    @State private var working = false

    var body: some View {
        let songs = model.pendingDeleteSongs
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("READY TO DELETE").font(Theme.mono(12)).tracking(1).foregroundStyle(Theme.muted)
                    Text(selected.count == 1 ? "1 song" : "\(selected.count) songs").font(Theme.display(34))
                }
                Spacer()
                Text(Format.totalTime(songs.filter { selected.contains($0.id) }))
                    .font(Theme.mono(13))
                    .foregroundStyle(Theme.muted)
            }

            if songs.isEmpty {
                Text("Nothing is marked for deletion. Swipe a session first.")
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .panel()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(songs) { song in
                            HStack(spacing: 12) {
                                Toggle("", isOn: binding(for: song.id))
                                    .toggleStyle(.checkbox)
                                    .labelsHidden()
                                SongRow(song: song, detail: detail(for: song)) {
                                    Text(Format.duration(song.duration))
                                        .font(Theme.mono(12))
                                        .foregroundStyle(Theme.muted)
                                }
                            }
                            .padding(.horizontal, 14)
                            Rectangle().fill(Theme.line).frame(height: 1)
                        }
                    }
                }
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line))
            }

            HStack(spacing: 10) {
                Toggle("Save a backup list (CSV) to Documents first", isOn: $backup)
                    .toggleStyle(.checkbox)
                Spacer()
                Button("Not now") { model.screen = .home }
                    .buttonStyle(.secondary)
                Button(selected.count == 1 ? "Delete 1 song" : "Delete \(selected.count) songs") { confirming = true }
                    .buttonStyle(.danger)
                    .disabled(selected.isEmpty || working)
            }
            Text("Deleting removes the songs from your library on every device through iCloud. Apple Music has no undo for this. Songs you untick count as kept.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
        .padding(32)
        .frame(maxWidth: 900)
        .onAppear { selected = Set(songs.map(\.id)) }
        .confirmationDialog("Delete \(selected.count) songs from your library?", isPresented: $confirming) {
            Button("Delete", role: .destructive) {
                Task {
                    working = true
                    let ok = await model.confirmReview(selected: selected, backup: backup)
                    working = false
                    if ok { model.screen = .home }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They'll be removed on all your devices. This can't be undone.")
        }
        .overlay {
            if working {
                ProgressView("Deleting…").padding(24).panel()
            }
        }
    }

    private func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { selected.contains(id) },
            set: { isOn in
                if isOn { selected.insert(id) } else { selected.remove(id) }
            })
    }

    private func detail(for song: Song) -> String {
        let plays = song.playCount == 1 ? "1 play" : "\(song.playCount) plays"
        return "\(song.artist) · \(plays) · added \(Format.monthYear(song.dateAdded))"
    }
}

struct SecondChanceView: View {
    @Environment(AppModel.self) private var model
    @State private var items: [SecondChanceItem] = []
    @State private var working = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SECOND CHANCE ROUND").font(Theme.mono(12)).tracking(1).foregroundStyle(Theme.muted)
                    Text(items.count == 1 ? "1 song" : "\(items.count) songs").font(Theme.display(34))
                }
                Spacer()
                Button("Back") { model.stopClip(); model.screen = .home }
                    .buttonStyle(.secondary)
                Button("Apply choices") {
                    Task {
                        working = true
                        await model.applySecondChance(items)
                        working = false
                    }
                }
                .buttonStyle(.primary)
                .disabled(items.isEmpty || working)
            }

            Text("Sift suggests a choice based on whether you played each song since you added it. Click ▶ to hear a clip, and change any choice you disagree with.")
                .foregroundStyle(Theme.muted)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach($items) { $item in
                        SongRow(song: item.song, detail: item.song.artist) {
                            sincePill(item)
                            Button { model.playClip(for: item.song) } label: { Image(systemName: "play.circle.fill").font(.title2) }
                                .buttonStyle(.plain)
                                .foregroundStyle(Theme.brand)
                                .help("Play a clip")
                            Picker("Choice", selection: $item.choice) {
                                ForEach(SecondChanceChoice.allCases) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 240)
                        }
                        .padding(.horizontal, 14)
                        Rectangle().fill(Theme.line).frame(height: 1)
                    }
                }
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line))
        }
        .padding(32)
        .frame(maxWidth: 900)
        .onAppear { items = model.secondChanceRound() }
    }

    @ViewBuilder
    private func sincePill(_ item: SecondChanceItem) -> some View {
        if item.playsSince > 0 {
            Pill("Played \(item.playsSince)× since", decision: .keep)
        } else if item.skipsSince > 0 {
            Pill("Skipped \(item.skipsSince)×")
        } else {
            Pill("Not played")
        }
    }
}
