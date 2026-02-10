import SwiftUI

struct ContentView: View {
    var body: some View {
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
    }
}

#Preview {
    ContentView()
}
