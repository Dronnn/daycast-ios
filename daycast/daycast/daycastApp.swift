import SwiftUI
import SwiftData

@main
struct daycastApp: App {

    let modelContainer: ModelContainer

    init() {
        SharedTokenStorage.migrateFromStandardDefaultsIfNeeded()

        let schema = Schema([
            CachedInputItem.self,
            CachedInputItemEdit.self,
            CachedGeneration.self,
            CachedGenerationResult.self,
            CachedDaySummary.self,
            CachedChannelSetting.self,
            CachedBlogPost.self,
            PendingSyncOperation.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        CacheService.shared.configure(with: modelContainer)
        SyncService.shared.configure(with: modelContainer)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    SyncService.shared.startObservingConnectivity()
                    NotificationManager.shared.rescheduleAll()
                }
        }
        .modelContainer(modelContainer)
    }
}
