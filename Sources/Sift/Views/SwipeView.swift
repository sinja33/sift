import SwiftUI

struct SwipeView: View {
    @Environment(AppModel.self) private var model
    @State private var drag: CGSize = .zero
    @State private var leaving = false
    @FocusState private var focused: Bool

    private let threshold: CGFloat = 110

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { model.endSession() } label: { Label("Home", systemImage: "chevron.left") }
                    .buttonStyle(.secondary)
                Spacer()
                if !model.queue.isEmpty {
                    Text("\(min(model.index + 1, model.queue.count)) of \(model.queue.count)")
                        .font(Theme.mono(13))
                        .foregroundStyle(Theme.muted)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)

            HStack(alignment: .top, spacing: 28) {
                VStack(spacing: 22) {
                    if let song = model.current {
                        ZStack {
                            if let next = model.next {
                                SongCard(song: next, isTop: false)
                                    .scaleEffect(0.95)
                                    .offset(y: 12)
                                    .opacity(0.6)
                            }
                            SongCard(song: song, isTop: true, drag: drag)
                                .id(song.id)
                                .offset(drag)
                                .rotationEffect(.degrees(drag.width / 18))
                                .gesture(dragGesture)
                        }
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

                sidebar.frame(width: 220)
            }
            .padding(28)
            Spacer(minLength: 0)
        }
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onAppear { focused = true }
        .onKeyPress(.leftArrow) { commit(model.leftDecision); return .handled }
        .onKeyPress(.rightArrow) { commit(model.rightDecision); return .handled }
        .onKeyPress(.upArrow) { commit(.secondChance); return .handled }
        .onKeyPress(.space) { model.playClipForCurrent(); return .handled }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("This session").font(.headline)
                tallyRow(.delete)
                tallyRow(.secondChance)
                tallyRow(.keep)
                Button("Undo") { model.undo() }
                    .buttonStyle(.secondary)
                    .keyboardShortcut("z", modifiers: .command)
                    .disabled(model.history.isEmpty)
            }
            .panel()

            Toggle("Play clips", isOn: Binding(get: { model.clipsEnabled }, set: { model.setClipsEnabled($0) }))
                .toggleStyle(.switch)

            VStack(alignment: .leading, spacing: 8) {
                keyHint("←", model.leftDecision.label)
                keyHint("→", model.rightDecision.label)
                keyHint("↑", Decision.secondChance.label)
                keyHint("Space", "Replay clip")
                keyHint("⌘Z", "Undo")
            }
            .font(.callout)
            .foregroundStyle(Theme.muted)
        }
    }

    private func tallyRow(_ decision: Decision) -> some View {
        HStack {
            Text(decision.label)
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
        guard !leaving, model.current != nil else { return }
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
            model.decide(decision)
            drag = .zero
            leaving = false
        }
    }
}

struct SongCard: View {
    let song: Song
    let isTop: Bool
    var drag: CGSize = .zero

    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ArtworkView(song: song, loads: isTop)
                .onTapGesture { if isTop { model.playClipForCurrent() } }
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title).font(Theme.display(20)).lineLimit(2)
                Text([song.artist, song.album].filter { !$0.isEmpty }.joined(separator: " · "))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            ClipBar(song: song, active: isTop)
            Rectangle().fill(Theme.line).frame(height: 1)
            HStack {
                StatView(value: "\(song.playCount)", label: "plays")
                Spacer()
                StatView(value: Format.age(song.dateAdded), label: "in library")
                Spacer()
                StatView(value: Format.monthYear(song.lastPlayed), label: "last played")
            }
        }
        .padding(16)
        .frame(width: 300)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line))
        .shadow(color: .black.opacity(0.10), radius: 16, y: 8)
        .overlay(alignment: .topLeading) {
            Stamp(decision: model.rightDecision, angle: -12).opacity(strength(drag.width))
        }
        .overlay(alignment: .topTrailing) {
            Stamp(decision: model.leftDecision, angle: 12).opacity(strength(-drag.width))
        }
        .overlay(alignment: .center) {
            Stamp(decision: .secondChance, angle: 0).opacity(abs(drag.width) < 60 ? strength(-drag.height) : 0)
        }
    }

    private func strength(_ distance: CGFloat) -> Double {
        Double(min(1, max(0, distance / 110)))
    }
}

private struct Stamp: View {
    let decision: Decision
    let angle: Double

    var body: some View {
        Text(decision.label.uppercased())
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
                    Text("clip from \(Format.duration(song.clipStart))")
                    Spacer()
                    Text("\(Format.duration(min(elapsed, model.clipLength))) / \(Format.duration(model.clipLength))")
                }
                .font(Theme.mono(11))
                .foregroundStyle(Theme.muted)
            }
        }
    }
}

private struct SessionDoneView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 14) {
            Text(model.queue.isEmpty ? "Nothing to swipe" : "Session done").font(Theme.display(26))
            Text(model.queue.isEmpty
                 ? "No songs match this filter right now. Try another one on the home screen."
                 : "\(model.count(of: .delete)) marked for deletion, \(model.count(of: .secondChance)) in Second Chance, \(model.count(of: .keep)) kept.")
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                if !model.state.pendingDelete.isEmpty {
                    Button("Review and delete") { model.stopClip(); model.screen = .review }.buttonStyle(.danger)
                }
                Button("Another session") { model.startSession() }.buttonStyle(.primary)
            }
        }
        .padding(.top, 80)
        .frame(maxWidth: 420)
    }
}
