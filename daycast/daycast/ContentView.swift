import SwiftUI

struct ContentView: View {
    @State private var isAuthenticated = APIService.shared.isAuthenticated
    @State private var selectedTab = "feed"
    private var network = NetworkMonitor.shared

    var body: some View {
        if isAuthenticated {
            TabView(selection: $selectedTab) {
                Tab("History", systemImage: "clock.fill", value: "history") {
                    HistoryView()
                }
                Tab("Channels", systemImage: "slider.horizontal.3", value: "channels") {
                    ChannelsView(isAuthenticated: $isAuthenticated)
                }
                Tab("Feed", systemImage: "bubble.left.fill", value: "feed") {
                    FeedView()
                }
                Tab("Generate", systemImage: "bolt.fill", value: "generate") {
                    GenerateView()
                }
                Tab("Blog", systemImage: "globe", value: "blog") {
                    BlogView()
                }
            }
            .tint(.blue)
            .overlay(alignment: .top) {
                if !network.isConnected {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                        Text("Offline — showing cached data")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: network.isConnected)
        } else {
            LoginView(isAuthenticated: $isAuthenticated)
        }
    }
}

#Preview {
    ContentView()
}
