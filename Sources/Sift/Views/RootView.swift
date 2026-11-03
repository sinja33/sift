import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.paper.ignoresSafeArea()
            Group {
                switch model.screen {
                case .welcome: WelcomeView().transition(screenChange)
                case .home: HomeView().transition(screenChange)
                case .session: SwipeView().transition(screenChange)
                case .review: ReviewView().transition(screenChange)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if let toast = model.toast {
                ToastView(text: toast)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .foregroundStyle(Theme.ink)
        .preferredColorScheme(model.colorScheme)
        .animation(.easeOut(duration: 0.2), value: model.toast)
        .animation(.smooth(duration: 0.35), value: model.screen)
        .alert("Something went wrong", isPresented: errorShown) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .frame(minWidth: 640, minHeight: 560)
        .task { await model.start() }
    }

    private var screenChange: AnyTransition { .opacity.combined(with: .scale(scale: 0.985)) }

    private var errorShown: Binding<Bool> {
        Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
    }
}

struct WelcomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 20) {
            LogoMark(size: 96)
            Text("Clean up your library,\none song at a time")
                .font(Theme.display(30))
                .multilineTextAlignment(.center)
            Text("Sift reads your Music library to find the songs you never play.")
                .foregroundStyle(Theme.muted)
            VStack(alignment: .leading, spacing: 10) {
                checkRow("Reads play counts, skips and dates added")
                checkRow("Plays a short clip so you remember the song")
                checkRow("Deletes only the songs you confirm")
            }
            .frame(width: 340, alignment: .leading)
            .panel(padding: 22)
            Button {
                Task { await model.connect() }
            } label: {
                HStack(spacing: 8) {
                    if model.isLoading { ProgressView().controlSize(.small) }
                    Text(model.isLoading ? "Reading your library…" : "Connect to Music")
                }
            }
            .buttonStyle(.primary)
            .disabled(model.isLoading)
            Text("macOS will ask once whether Sift may control Music. Click OK.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
        .padding(56)
        .frame(maxWidth: 560)
    }

    private func checkRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.keep)
            Text(text)
        }
    }
}
