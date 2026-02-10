import SwiftUI

struct ContentView: View {
    @State private var isAuthenticated = APIService.shared.isAuthenticated
    @State private var selectedTab = "feed"

    var body: some View {
        if isAuthenticated {
            TabView(selection: $selectedTab) {
                Tab("Blog", systemImage: "globe", value: "blog") {
                    BlogView()
                }
                Tab("Generate", systemImage: "bolt.fill", value: "generate") {
                    GenerateView()
                }
                Tab("Feed", systemImage: "bubble.left.fill", value: "feed") {
                    FeedView()
                }
                Tab("Channels", systemImage: "slider.horizontal.3", value: "channels") {
                    ChannelsView()
                }
                Tab("History", systemImage: "clock.fill", value: "history") {
                    HistoryView()
                }
            }
            .tint(.blue)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        APIService.shared.clearAuth()
                        isAuthenticated = false
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } else {
            LoginView(isAuthenticated: $isAuthenticated)
        }
    }
}

#Preview {
    ContentView()
}
