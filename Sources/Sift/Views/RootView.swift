import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.paper.ignoresSafeArea()
            Group {
                switch model.screen {
                case .welcome: WelcomeView()
                case .home: HomeView()
                case .session: SwipeView()
                case .review: ReviewView()
                case .secondChance: SecondChanceView()
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
        .animation(.easeOut(duration: 0.2), value: model.toast)
        .alert("Something went wrong", isPresented: errorShown) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .frame(minWidth: 860, minHeight: 640)
        .task { await model.start() }
    }

    private var errorShown: Binding<Bool> {
        Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
    }
}

struct WelcomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 20) {
            LogoMark(size: 96)
            Text("Clean up your library, one song at a time")
                .font(Theme.display(30))
                .multilineTextAlignment(.center)
            Text("Sift reads your Music library to find the songs you never play.")
                .foregroundStyle(Theme.muted)
            VStack(alignment: .leading, spacing: 10) {
                checkRow("Reads play counts, skips and dates added")
                checkRow("Plays a short clip so you remember the song")
                checkRow("Deletes only the songs you confirm")
            }
            .panel()
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
        .padding(40)
        .frame(maxWidth: 560)
    }

    private func checkRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.keep)
            Text(text)
        }
    }
}
