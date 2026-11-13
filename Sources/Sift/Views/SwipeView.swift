import SwiftUI

struct SwipeView: View {
    @Environment(AppModel.self) private var model
    @State private var drag: CGSize = .zero
    @State private var leaving = false
    @FocusState private var focused: Bool

    private let threshold: CGFloat = 110

    @State private var cardHeight: CGFloat = 500

    private let cardWidth: CGFloat = 300
    private let sidebarWidth: CGFloat = 220
    private let columnWidth: CGFloat = 280

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= 860
            let large = geo.size.width >= 1100
            let availableWidth = geo.size.width - 80 - (large ? 2 * (columnWidth + 28) : wide ? sidebarWidth + 28 : 0)
            // The deck is drawn at its natural size and scaled to fill what is left of the window.
            let availableHeight = geo.size.height - 64 - 24 - 80 - 22 - 56
            let scale = min(large ? 1.7 : 1.5, max(0.7, min(availableWidth / cardWidth, availableHeight / cardHeight)))
            VStack(spacing: 0) {
                header(compact: !wide, showsTrash: !large)
                progressBar
                HStack(alignment: .top, spacing: 28) {
                    if large { sidebar.frame(width: columnWidth) }
                    VStack(spacing: 22) {
                        if let stop = model.artistStop {
                            artistStopCard(stop)
                                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        } else if let song = model.current {
                            deck(song: song, scale: scale)
                            HStack(spacing: 18) {
                                ActionButton(decision: model.leftDecision) { commit(model.leftDecision) }
                                ActionButton(decision: .secondChance, size: 46) { commit(.secondChance) }
                                ActionButton(decision: model.rightDecision) { commit(model.rightDecision) }
                            }
                        } else {
                            SessionDoneView()
                        }
                    }
                    .frame(maxWidth: .infinity)

                    if large { upNext.frame(width: columnWidth) } else if wide { sidebar.frame(width: sidebarWidth) }
                }
                .padding(40)
                Spacer(minLength: 0)
            }
        }
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onAppear { focused = true }
        .onKeyPress(.leftArrow) { commit(model.leftDecision); return .handled }
        .onKeyPress(.rightArrow) { commit(model.rightDecision); return .handled }
        .onKeyPress(.upArrow) { commit(.secondChance); return .handled }
        .onKeyPress(.return) {
            guard model.artistStop != nil else { return .ignored }
            model.acceptArtistStop(); return .handled
        }
        .onKeyPress(.escape) {
            guard model.artistStop != nil else { return .ignored }
            model.declineArtistStop(); return .handled
        }
        .onKeyPress(.space) { model.playClipForCurrent(); return .handled }
        .onKeyPress("s") { model.skipCurrent(); return .handled }
        .onPreferenceChange(CardHeightKey.self) { if $0 > 0 { cardHeight = $0 } }
    }

    private func header(compact: Bool, showsTrash: Bool) -> some View {
        HStack {
            Button { model.endSession() } label: { Label("Home", systemImage: "chevron.left") }
                .buttonStyle(.secondary)
            if model.sessionKind == .secondChance {
                Text("SECOND CHANCE ROUND").font(Theme.mono(12)).tracking(1).foregroundStyle(Theme.muted)
                    .padding(.leading, 8)
            } else if let artist = model.sessionArtist {
                Text("ARTIST · \(artist.uppercased())").font(Theme.mono(12)).tracking(1).foregroundStyle(Theme.muted)
                    .lineLimit(1).padding(.leading, 8)
            }
            Spacer()
            if compact {
                HStack(spacing: 6) {
                    Pill("\(model.count(of: .delete))", decision: .delete)
                    Pill("\(model.count(of: .secondChance))", decision: .secondChance)
                    Pill("\(model.count(of: .keep))", decision: .keep)
                }
            }
            if showsTrash && !model.state.pendingDelete.isEmpty {
                // Only the largest windows show the ready-to-delete panel, so the way to the review sits up here.
                Button { model.openReview() } label: {
                    Label("\(model.state.pendingDelete.count)", systemImage: "trash")
                }
                .buttonStyle(.secondary)
                .help("Review and delete the songs marked so far")
                .padding(.leading, 8)
            }
            if model.current != nil {
                Button { model.undo() } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 40, height: 40)
                        .background(Theme.surface2, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .pointerCursor()
                .keyboardShortcut("z", modifiers: .command)
                .disabled(model.history.isEmpty || model.artistStop != nil)
                .opacity(model.history.isEmpty || model.artistStop != nil ? 0.4 : 1)
                .help("Undo (⌘Z)")
                .padding(.leading, 8)
            }
            if !model.queue.isEmpty {
                Text("\(min(model.index + 1, model.queue.count)) of \(model.queue.count)")
                    .font(Theme.mono(13))
                    .foregroundStyle(Theme.muted)
                    .padding(.leading, 8)
            }
        }
        .padding(.horizontal, 40)
        .padding(.top, 28)
    }

    private var progressBar: some View {
        let total = max(1, model.queue.count)
        let done = CGFloat(min(model.index, total)) / CGFloat(total)
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surface2)
                Capsule().fill(Theme.brand).frame(width: max(10, geo.size.width * done))
            }
        }
        .frame(height: 10)
        .padding(.horizontal, 40)
        .padding(.top, 18)
        .animation(.spring(duration: 0.4), value: model.index)
        .opacity(model.queue.isEmpty ? 0 : 1)
    }

    private func deck(song: Song, scale: CGFloat) -> some View {
        ZStack {
            if let next = model.next {
                SongCard(song: next, isTop: false)
                    .scaleEffect(0.95)
                    .offset(y: 12)
                    .opacity(0.6)
            }
            SongCard(song: song, isTop: true, drag: drag)
                .background(GeometryReader { proxy in
                    Color.clear.preference(key: CardHeightKey.self, value: proxy.size.height)
                })
                .id(song.id)
                .offset(drag)
                .rotationEffect(.degrees(drag.width / 18))
                .gesture(dragGesture)
        }
        .fixedSize()
        .scaleEffect(scale)
        .frame(width: cardWidth * scale, height: (cardHeight + 12) * scale)
    }

    /// Offered after the third deletion by one artist, in place of the next card.
    private func artistStopCard(_ stop: AppModel.ArtistStop) -> some View {
        VStack(spacing: 14) {
            Mascot(mood: .wink, size: 64)
            ArtistAvatar(artist: stop.artist, size: 88)
            Text("That's \(stop.deleted) songs by \(stop.artist)")
                .font(Theme.display(24))
                .multilineTextAlignment(.center)
                .lineLimit(3)
            Text("They have \(stop.remaining) more in your library. Go through them now, then pick up where you left off?")
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 10) {
                Button("Go through their songs") { model.acceptArtistStop() }.buttonStyle(.primary)
                Button("Not now") { model.declineArtistStop() }.buttonStyle(.secondary)
            }
            .padding(.top, 6)
            Text("Return to go, Esc to skip").font(Theme.mono(12)).foregroundStyle(Theme.muted)
        }
        .padding(24)
        .frame(width: 320)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line))
        .shadow(color: .black.opacity(0.10), radius: 16, y: 8)
    }

    /// Session stats, the clip switch and the keys. The ready-to-delete panel only appears on the largest windows,
    /// under Up next; smaller windows reach the review from the trash button in the header.
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text(model.sessionKind == .secondChance ? "This round" : "This session").font(.headline)
                tallyRow(.delete)
                tallyRow(.secondChance)
                tallyRow(.keep)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .panel()

            Toggle("Play clips", isOn: Binding(get: { model.clipsEnabled }, set: { model.setClipsEnabled($0) }))
                .toggleStyle(.switch)
                .pointerCursor()

            VStack(alignment: .leading, spacing: 8) {
                keyHint("←", model.label(for: model.leftDecision))
                keyHint("→", model.label(for: model.rightDecision))
                keyHint("↑", model.label(for: .secondChance))
                keyHint("S", "Skip song")
                keyHint("⌘Z", "Undo")
                keyHint("Space", "Replay clip")
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.muted)
        }
    }

    /// The songs after this one, shown when the window is big enough to have room for them.
    private var upNext: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Up next").font(.headline)
                let next = model.queue.dropFirst(model.index + 1).prefix(4)
                if next.isEmpty {
                    Text("That's the last one.").font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
                ForEach(Array(next), id: \.id) { song in
                    HStack(spacing: 12) {
                        ArtworkView(song: song, loads: false, cornerRadius: 8).frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(song.title).fontWeight(.semibold).lineLimit(1)
                            Text(song.artist).font(.system(size: 12)).foregroundStyle(Theme.muted).lineLimit(1)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .panel()

            readyToDelete
        }
    }

    /// Songs marked for deletion so far, with a way to review them without finishing the session first.
    private var readyToDelete: some View {
        let count = model.state.pendingDelete.count
        return VStack(alignment: .leading, spacing: 4) {
            Text("READY TO DELETE").font(Theme.mono(12)).tracking(1).foregroundStyle(Theme.muted)
            Text(count == 1 ? "1 song" : "\(count) songs").font(Theme.display(24)).contentTransition(.numericText())
            Text("They stay in your library until you confirm.").font(.system(size: 12)).foregroundStyle(Theme.muted)
            Button("Review and delete") { model.openReview() }
                .buttonStyle(.secondary)
                .disabled(count == 0)
                .opacity(count == 0 ? 0.5 : 1)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel()
        .animation(.smooth(duration: 0.3), value: count)
    }

    private func tallyRow(_ decision: Decision) -> some View {
        HStack {
            Text(model.label(for: decision))
            Spacer()
            Pill("\(model.count(of: decision))", decision: decision)
        }
    }

    private func keyHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 8) {
            KeyCap(key: key)
            Text(label)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { drag = $0.translation }
            .onEnded { value in
                let t = value.translation
                if t.width > threshold {
                    commit(model.rightDecision)
                } else if t.width < -threshold {
                    commit(model.leftDecision)
                } else if t.height < -threshold && abs(t.width) < 80 {
                    commit(.secondChance)
                } else {
                    withAnimation(.spring(duration: 0.3)) { drag = .zero }
                }
            }
    }

    /// Flies the card off screen, then records the decision.
    private func commit(_ decision: Decision) {
        guard !leaving, model.current != nil, model.artistStop == nil else { return }
        leaving = true
        let target: CGSize
        switch decision {
        case .secondChance: target = CGSize(width: 0, height: -800)
        case model.rightDecision: target = CGSize(width: 900, height: drag.height)
        default: target = CGSize(width: -900, height: drag.height)
        }
        withAnimation(.easeIn(duration: 0.2)) { drag = target }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.smooth(duration: 0.3)) { model.decide(decision) }
            drag = .zero
            leaving = false
        }
    }
}

private struct CardHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

struct SongCard: View {
    let song: Song
    let isTop: Bool
    var drag: CGSize = .zero

    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ArtworkView(song: song, loads: isTop)
                .overlay {
                    if isTop && model.clipLoading {
                        ZStack {
                            Color.black.opacity(0.45)
                            VStack(spacing: 14) {
                                LoadingRing()
                                Text("Loading song…").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .animation(.easeOut(duration: 0.15), value: model.clipLoading)
                .onTapGesture { if isTop { model.playClipForCurrent() } }
                .pointerCursor()
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title).font(Theme.display(24)).lineLimit(2)
                Text([song.artist, song.album].filter { !$0.isEmpty }.joined(separator: " · "))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            ClipBar(song: song, active: isTop)
            if let info = model.chanceInfo(for: song) {
                HStack(spacing: 8) {
                    Image(systemName: "clock").font(.system(size: 13, weight: .bold))
                    Text(chanceBanner(info.playsSince, info.skipsSince))
                        .font(.system(size: 13, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(info.playsSince > 0 ? Theme.keep : Theme.chance)
                .padding(10)
                .background(info.playsSince > 0 ? Theme.keepSoft : Theme.chanceSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Rectangle().fill(Theme.line).frame(height: 1)
                HStack {
                    StatView(value: "\(info.playsSince)", label: "plays since")
                    Spacer()
                    StatView(value: Format.age(info.added), label: "in second chance")
                    Spacer()
                    StatView(value: "\(song.playCount)", label: "total plays")
                }
            } else {
                Rectangle().fill(Theme.line).frame(height: 1)
                HStack {
                    StatView(value: "\(song.playCount)", label: "plays")
                    Spacer()
                    StatView(value: Format.age(song.dateAdded), label: "in library")
                    Spacer()
                    StatView(value: song.lastPlayed == nil && song.playCount > 0 ? "unknown" : Format.monthYear(song.lastPlayed), label: "last played")
                }
            }
        }
        .padding(16)
        .frame(width: 300)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line))
        .shadow(color: .black.opacity(0.10), radius: 16, y: 8)
        .overlay(alignment: .topLeading) {
            Stamp(decision: model.rightDecision, label: model.label(for: model.rightDecision), angle: -12).opacity(strength(drag.width))
        }
        .overlay(alignment: .topTrailing) {
            Stamp(decision: model.leftDecision, label: model.label(for: model.leftDecision), angle: 12).opacity(strength(-drag.width))
        }
        .overlay(alignment: .center) {
            Stamp(decision: .secondChance, label: model.label(for: .secondChance), angle: 0).opacity(abs(drag.width) < 60 ? strength(-drag.height) : 0)
        }
    }

    private func chanceBanner(_ plays: Int, _ skips: Int) -> String {
        if plays > 0 { return "Played \(plays)× since you added it to Second Chance" }
        if skips > 0 { return "Skipped \(skips)× since you added it to Second Chance" }
        return "Not played since you added it to Second Chance"
    }

    private func strength(_ distance: CGFloat) -> Double {
        Double(min(1, max(0, distance / 110)))
    }
}

private struct Stamp: View {
    let decision: Decision
    let label: String
    let angle: Double

    var body: some View {
        Text(label.uppercased())
            .font(Theme.display(22))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(decision.tint)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(decision.tint, lineWidth: 3))
            .rotationEffect(.degrees(angle))
            .padding(26)
            .allowsHitTesting(false)
    }
}

private struct ClipBar: View {
    let song: Song
    let active: Bool
    @Environment(AppModel.self) private var model

    var body: some View {
        if active && model.clipUnplayable {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 12))
                Text("Can't play this one. Press S to skip it.")
                    .font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 0)
                Button("Skip") { model.skipCurrent() }
                    .buttonStyle(.plain)
                    .pointerCursor()
                    .font(.system(size: 12, weight: .bold))
                    .underline()
            }
            .foregroundStyle(Theme.delete)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Theme.deleteSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            timeline
        }
    }

    private var timeline: some View {
        TimelineView(.animation(minimumInterval: 0.1, paused: !active || model.clipStartedAt == nil)) { context in
            let elapsed = active ? model.clipStartedAt.map { context.date.timeIntervalSince($0) } ?? 0 : 0
            let progress = min(1, elapsed / model.clipLength)
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.surface2)
                        Capsule().fill(Theme.brand).frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 4)
                HStack {
                    Text(model.clipIsPreview ? "Apple preview" : "clip from \(Format.duration(song.clipStart))")
                    Spacer()
                    Text("\(Format.duration(min(elapsed, model.clipLength))) / \(Format.duration(model.clipLength))")
                }
                .font(Theme.mono(12))
                .foregroundStyle(Theme.muted)
            }
        }
    }
}

private struct SessionDoneView: View {
    @Environment(AppModel.self) private var model
    @State private var shown = false

    var body: some View {
        let chance = model.sessionKind == .secondChance
        VStack(spacing: 14) {
            Mascot(mood: model.queue.isEmpty ? .sleepy : chance ? .happy : .cheer, size: 130, animated: true)
                .scaleEffect(shown ? 1 : 0.3)
                .opacity(shown ? 1 : 0)
                .animation(.spring(duration: 0.7, bounce: 0.5), value: shown)
            Text(model.queue.isEmpty ? "Nothing to swipe" : chance ? "Round done!" : "Session complete!").font(Theme.display(32))
                .rise(shown, delay: 0.15)
            Text(model.queue.isEmpty
                 ? "Every song is either new, recently kept or already waiting. Try another filter on the home screen, or come back after you've listened to more."
                 : chance
                    ? "\(model.count(of: .delete)) to delete, \(model.count(of: .secondChance)) to ask again, \(model.count(of: .keep)) kept."
                    : "\(model.count(of: .delete)) marked for deletion, \(model.count(of: .secondChance)) in Second Chance, \(model.count(of: .keep)) kept.")
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .rise(shown, delay: 0.25)
            HStack(spacing: 10) {
                if model.queue.isEmpty {
                    Button("Back home") { model.endSession() }.buttonStyle(.primary)
                } else if chance {
                    Button("Apply choices") { Task { await model.finishSecondChanceRound() } }.buttonStyle(.primary)
                } else {
                    if !model.state.pendingDelete.isEmpty {
                        Button("Review and delete") { model.openReview() }.buttonStyle(.secondary)
                    }
                    Button("Another session") { model.startSession() }.buttonStyle(.primary)
                }
            }
            .rise(shown, delay: 0.35)
        }
        .padding(.top, 80)
        .frame(maxWidth: 420)
        .onAppear { shown = true }
    }
}

private extension View {
    /// Fades in and floats up once `shown` turns true.
    func rise(_ shown: Bool, delay: Double) -> some View {
        self.opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 16)
            .animation(.spring(duration: 0.55, bounce: 0.15).delay(delay), value: shown)
    }
}
