import SwiftUI

/// The screen shown while the app launches: the app mark, its name, and a
/// spinner while it gets ready (loading the person's store and list, say).
///
/// It uses only system colors, so it follows light and dark mode on its own.
/// It has no timer of its own: whoever shows it decides when to replace it,
/// so it never holds the app up longer than the work actually takes.
struct SplashView: View {
    var appName: String = "RHD Shopping"
    var showsProgress: Bool = true

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: "cart")
                .font(.system(size: 64, weight: .regular))
                .foregroundStyle(.white)
                .frame(width: 128, height: 128)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                .accessibilityHidden(true)

            Text(appName)
                .font(.largeTitle.bold())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) {
            if showsProgress {
                ProgressView()
                    .controlSize(.regular)
                    .padding(.bottom, 84)
                    .accessibilityLabel("Loading")
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// Shows `SplashView` until `isReady` turns true, then fades to `content`.
///
/// ```swift
/// WindowGroup {
///     LaunchGate(isReady: model.isReady) { RootView() }
///         .task { await model.prepare() }
/// }
/// ```
struct LaunchGate<Content: View>: View {
    let isReady: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            if isReady {
                content().transition(.opacity)
            } else {
                SplashView().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isReady)
    }
}

#if DEBUG
#Preview("Splash") {
    SplashView()
}

#Preview("Splash, dark") {
    SplashView().preferredColorScheme(.dark)
}

#Preview("Launch gate, ready") {
    LaunchGate(isReady: true) { Text("App content") }
}
#endif
