import Foundation
import SwiftData

@MainActor
final class CacheService {
    static let shared = CacheService()

    var modelContext: ModelContext?

    private let maxCacheDays = 20

    private init() {}

    func configure(with container: ModelContainer) {
        self.modelContext = container.mainContext
    }

    // MARK: - Input Items

    func getCachedItems(date: String) -> [InputItem] {
        guard let ctx = modelContext else { return [] }
        let predicate = #Predicate<CachedInputItem> { $0.date == date }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.createdAt)])
        return (try? ctx.fetch(descriptor))?.map { $0.toApiModel() } ?? []
    }

    func cacheItems(_ items: [InputItem], for date: String) {
        guard let ctx = modelContext else { return }
        clearCachedItemsInternal(date: date, context: ctx)
        for item in items {
            ctx.insert(CachedInputItem(from: item))
        }
        trySave(ctx)
        evictOldData()
    }

    func cacheItem(_ item: InputItem) {
        guard let ctx = modelContext else { return }
        // Remove existing with same ID
        let itemId = item.id
        let predicate = #Predicate<CachedInputItem> { $0.itemId == itemId }
        if let existing = try? ctx.fetch(FetchDescriptor(predicate: predicate)).first {
            ctx.delete(existing)
        }
        ctx.insert(CachedInputItem(from: item))
        trySave(ctx)
    }

    func updateCachedItem(id: String, content: String) {
        guard let ctx = modelContext else { return }
        let predicate = #Predicate<CachedInputItem> { $0.itemId == id }
        if let item = try? ctx.fetch(FetchDescriptor(predicate: predicate)).first {
            item.content = content
            item.updatedAt = ISO8601DateFormatter().string(from: .now)
            trySave(ctx)
        }
    }

    func deleteCachedItem(id: String) {
        guard let ctx = modelContext else { return }
        let predicate = #Predicate<CachedInputItem> { $0.itemId == id }
        if let item = try? ctx.fetch(FetchDescriptor(predicate: predicate)).first {
            ctx.delete(item)
            trySave(ctx)
        }
    }

    func clearCachedDay(date: String) {
        guard let ctx = modelContext else { return }
        clearCachedItemsInternal(date: date, context: ctx)
        trySave(ctx)
    }

    // MARK: - Generations

    func getCachedGenerations(date: String) -> [Generation] {
        guard let ctx = modelContext else { return [] }
        let predicate = #Predicate<CachedGeneration> { $0.date == date }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.createdAt)])
        return (try? ctx.fetch(descriptor))?.map { $0.toApiModel() } ?? []
    }

    func cacheGenerations(_ generations: [Generation], for date: String) {
        guard let ctx = modelContext else { return }
        // Remove existing for date
        let predicate = #Predicate<CachedGeneration> { $0.date == date }
        if let existing = try? ctx.fetch(FetchDescriptor(predicate: predicate)) {
            for gen in existing { ctx.delete(gen) }
        }
        for gen in generations {
            ctx.insert(CachedGeneration(from: gen))
        }
        trySave(ctx)
    }

    // MARK: - Day Summaries

    func getCachedDaySummaries() -> [DaySummary] {
        guard let ctx = modelContext else { return [] }
        let descriptor = FetchDescriptor<CachedDaySummary>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? ctx.fetch(descriptor))?.map { $0.toApiModel() } ?? []
    }

    func cacheDaySummaries(_ summaries: [DaySummary]) {
        guard let ctx = modelContext else { return }
        // Remove all existing summaries
        try? ctx.delete(model: CachedDaySummary.self)
        for summary in summaries {
            ctx.insert(CachedDaySummary(from: summary))
        }
        trySave(ctx)
    }

    // MARK: - Channel Settings

    func getCachedChannelSettings() -> [ChannelSetting] {
        guard let ctx = modelContext else { return [] }
        let descriptor = FetchDescriptor<CachedChannelSetting>()
        return (try? ctx.fetch(descriptor))?.map { $0.toApiModel() } ?? []
    }

    func cacheChannelSettings(_ settings: [ChannelSetting]) {
        guard let ctx = modelContext else { return }
        try? ctx.delete(model: CachedChannelSetting.self)
        for setting in settings {
            ctx.insert(CachedChannelSetting(from: setting))
        }
        trySave(ctx)
    }

    // MARK: - Local Item Creation

    func createLocalItem(type: InputItemType, content: String, date: String) -> InputItem {
        let tempId = "temp_\(UUID().uuidString)"
        let now = ISO8601DateFormatter().string(from: .now)
        let cached = CachedInputItem(
            itemId: tempId,
            type: type.rawValue,
            content: content,
            extractedText: nil,
            extractError: nil,
            date: date,
            cleared: false,
            createdAt: now,
            updatedAt: now,
            isLocal: true,
            localTempId: tempId
        )
        modelContext?.insert(cached)
        trySave(modelContext)
        return cached.toApiModel()
    }

    func remapItemId(tempId: String, serverId: String) {
        guard let ctx = modelContext else { return }
        let predicate = #Predicate<CachedInputItem> { $0.itemId == tempId }
        if let item = try? ctx.fetch(FetchDescriptor(predicate: predicate)).first {
            item.itemId = serverId
            item.isLocal = false
            item.localTempId = nil
            trySave(ctx)
        }
    }

    // MARK: - Eviction

    func evictOldData() {
        guard let ctx = modelContext else { return }
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .day, value: -maxCacheDays, to: .now) else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let cutoffStr = formatter.string(from: cutoff)

        // Evict old items
        let itemPredicate = #Predicate<CachedInputItem> { $0.date < cutoffStr }
        if let old = try? ctx.fetch(FetchDescriptor(predicate: itemPredicate)) {
            for item in old { ctx.delete(item) }
        }

        // Evict old generations
        let genPredicate = #Predicate<CachedGeneration> { $0.date < cutoffStr }
        if let old = try? ctx.fetch(FetchDescriptor(predicate: genPredicate)) {
            for gen in old { ctx.delete(gen) }
        }

        // Evict old summaries
        let sumPredicate = #Predicate<CachedDaySummary> { $0.date < cutoffStr }
        if let old = try? ctx.fetch(FetchDescriptor(predicate: sumPredicate)) {
            for sum in old { ctx.delete(sum) }
        }

        trySave(ctx)
    }

    // MARK: - Private

    private func clearCachedItemsInternal(date: String, context: ModelContext) {
        let predicate = #Predicate<CachedInputItem> { $0.date == date }
        if let items = try? context.fetch(FetchDescriptor(predicate: predicate)) {
            for item in items { context.delete(item) }
        }
    }

    private func trySave(_ context: ModelContext?) {
        try? context?.save()
    }
}
