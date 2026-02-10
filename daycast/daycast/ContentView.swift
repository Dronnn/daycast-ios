import SwiftUI

struct ContentView: View {
    @State private var isAuthenticated = APIService.shared.isAuthenticated

    var body: some View {
        if isAuthenticated {
            TabView {
                Tab("Feed", systemImage: "bubble.left.fill") {
                    FeedView()
                }
                Tab("Generate", systemImage: "bolt.fill") {
                    GenerateView()
                }
                Tab("Channels", systemImage: "slider.horizontal.3") {
                    ChannelsView()
                }
                Tab("History", systemImage: "clock.fill") {
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
