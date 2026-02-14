import Foundation

@MainActor
@Observable
final class DataRepository {
    static let shared = DataRepository()

    private let api = APIService.shared
    private let cache = CacheService.shared
    private let sync = SyncService.shared
    private let network = NetworkMonitor.shared

    private init() {}

    // MARK: - API Call Wrapper

    /// Wraps an API call, reporting success/failure to NetworkMonitor.
    private func apiCall<T>(_ block: () async throws -> T) async throws -> T {
        do {
            let result = try await block()
            network.reportSuccess()
            return result
        } catch {
            network.reportFailure(error)
            throw error
        }
    }

    /// Void version.
    private func apiCallVoid(_ block: () async throws -> Void) async throws {
        do {
            try await block()
            network.reportSuccess()
        } catch {
            network.reportFailure(error)
            throw error
        }
    }

    // MARK: - Input Items

    func fetchItems(date: String) async -> [InputItem] {
        if network.isConnected {
            do {
                let items = try await apiCall { try await self.api.fetchItems(date: date) }
                cache.cacheItems(items, for: date)
                return items
            } catch {
                return cache.getCachedItems(date: date)
            }
        }
        return cache.getCachedItems(date: date)
    }

    func createItem(type: InputItemType, content: String, date: String) async -> InputItem {
        if network.isConnected {
            do {
                let request = InputItemCreateRequest(type: type, content: content, date: date, importance: 5)
                let item = try await apiCall { try await self.api.createItem(request) }
                cache.cacheItem(item)
                return item
            } catch {
                // Fallback to local
            }
        }
        let localItem = cache.createLocalItem(type: type, content: content, date: date)
        sync.enqueueCreate(type: type, content: content, date: date, tempId: localItem.id)
        return localItem
    }

    func updateItem(id: String, content: String) async {
        cache.updateCachedItem(id: id, content: content)
        if network.isConnected {
            do {
                let updated = try await apiCall { try await self.api.updateItem(id: id, content: content) }
                cache.cacheItem(updated)
                return
            } catch {
                // Fallback to enqueue
            }
        }
        sync.enqueueUpdate(id: id, content: content)
    }

    func deleteItem(id: String) async {
        cache.deleteCachedItem(id: id)
        if network.isConnected {
            do {
                try await apiCallVoid { try await self.api.deleteItem(id: id) }
                return
            } catch {
                // Fallback to enqueue
            }
        }
        sync.enqueueDelete(id: id)
    }

    func clearDay(date: String) async {
        cache.clearCachedDay(date: date)
        if network.isConnected {
            do {
                try await apiCallVoid { try await self.api.clearDay(date: date) }
                return
            } catch {
                // Fallback to enqueue
            }
        }
        sync.enqueueClearDay(date: date)
    }

    // MARK: - Image Upload

    func uploadImage(imageData: Data, date: String, filename: String) async throws -> InputItem {
        if network.isConnected {
            do {
                let item = try await apiCall { try await self.api.uploadImage(imageData: imageData, date: date, filename: filename) }
                cache.cacheItem(item)
                return item
            } catch {
                // Fallback to local placeholder
            }
        }
        // Offline: create local placeholder and enqueue
        let localItem = cache.createLocalItem(type: .image, content: "[Image pending upload]", date: date)
        sync.enqueueUploadImage(imageData: imageData, date: date, filename: filename, tempId: localItem.id)
        return localItem
    }

    // MARK: - Days / History

    func fetchDays(search: String? = nil) async -> [DaySummary] {
        // Search requires server
        if let search, !search.isEmpty {
            if network.isConnected {
                do {
                    let response = try await apiCall { try await self.api.fetchDays(search: search) }
                    return response.items
                } catch {
                    return []
                }
            }
            return []
        }

        if network.isConnected {
            do {
                let response = try await apiCall { try await self.api.fetchDays() }
                cache.cacheDaySummaries(response.items)
                return response.items
            } catch {
                return cache.getCachedDaySummaries()
            }
        }
        return cache.getCachedDaySummaries()
    }

    func fetchDay(date: String) async -> DayResponse {
        if network.isConnected {
            do {
                let response = try await apiCall { try await self.api.fetchDay(date: date) }
                cache.cacheItems(response.inputItems, for: date)
                cache.cacheGenerations(response.generations, for: date)
                return response
            } catch {
                return cachedDayResponse(date: date)
            }
        }
        return cachedDayResponse(date: date)
    }

    // MARK: - Generation

    func generate(date: String) async throws -> Generation {
        guard network.isConnected else {
            throw OfflineError.requiresNetwork("You're offline. Connect to generate content.")
        }
        let generation = try await apiCall { try await self.api.generate(date: date) }
        // Cache the new generation
        var existing = cache.getCachedGenerations(date: date)
        existing.append(generation)
        cache.cacheGenerations(existing, for: date)
        return generation
    }

    func regenerate(generationId: String, channels: [String]? = nil, date: String) async throws -> Generation {
        guard network.isConnected else {
            throw OfflineError.requiresNetwork("You're offline. Connect to regenerate content.")
        }
        let generation = try await apiCall { try await self.api.regenerate(generationId: generationId, channels: channels) }
        var existing = cache.getCachedGenerations(date: date)
        existing.append(generation)
        cache.cacheGenerations(existing, for: date)
        return generation
    }

    // MARK: - Publishing

    func publishPost(resultId: String) async throws -> PublishedPostResponse {
        guard network.isConnected else {
            throw OfflineError.requiresNetwork("You're offline. Connect to publish.")
        }
        return try await apiCall { try await self.api.publishPost(resultId: resultId) }
    }

    func unpublishPost(postId: String) async throws {
        guard network.isConnected else {
            throw OfflineError.requiresNetwork("You're offline. Connect to unpublish.")
        }
        try await apiCallVoid { try await self.api.unpublishPost(postId: postId) }
    }

    func getPublishStatus(resultIds: [String]) async throws -> PublishStatusResponse {
        guard network.isConnected else {
            throw OfflineError.requiresNetwork("Publish status unavailable offline.")
        }
        return try await apiCall { try await self.api.getPublishStatus(resultIds: resultIds) }
    }

    // MARK: - Channel Settings

    func fetchChannelSettings() async -> [ChannelSetting] {
        if network.isConnected {
            do {
                let settings = try await apiCall { try await self.api.fetchChannelSettings() }
                cache.cacheChannelSettings(settings)
                return settings
            } catch {
                return cache.getCachedChannelSettings()
            }
        }
        return cache.getCachedChannelSettings()
    }

    func saveChannelSettings(_ settings: [ChannelSetting]) async {
        cache.cacheChannelSettings(settings)
        if network.isConnected {
            do {
                try await apiCallVoid { try await self.api.saveChannelSettings(settings) }
                return
            } catch {
                // Fallback to enqueue
            }
        }
        sync.enqueueSaveChannelSettings(settings)
    }

    // MARK: - Item Field Updates

    func updateItemImportance(id: String, importance: Int?) async {
        // Update cache immediately (local-first)
        cache.updateCachedItemImportance(id: id, importance: importance)

        if network.isConnected {
            do {
                let updated = try await apiCall { try await self.api.updateItemFields(id: id, importance: importance) }
                cache.cacheItem(updated)
            } catch {
                // Network failed — already cached locally, enqueue for sync
                sync.enqueueUpdateFields(id: id, importance: importance)
            }
        } else {
            // Offline — enqueue for sync when back online
            sync.enqueueUpdateFields(id: id, importance: importance)
        }
    }

    func updateItemIncludeInGeneration(id: String, include: Bool) async {
        // Update cache immediately (local-first)
        cache.updateCachedItemIncludeInGeneration(id: id, include: include)

        if network.isConnected {
            do {
                let updated = try await apiCall { try await self.api.updateItemFields(id: id, includeInGeneration: include) }
                cache.cacheItem(updated)
            } catch {
                sync.enqueueUpdateFields(id: id, includeInGeneration: include)
            }
        } else {
            sync.enqueueUpdateFields(id: id, includeInGeneration: include)
        }
    }

    // MARK: - Publish Input

    func publishInputItem(inputItemId: String) async throws -> PublishedPostResponse {
        guard network.isConnected else {
            throw OfflineError.requiresNetwork("You're offline. Connect to publish.")
        }
        return try await apiCall { try await self.api.publishInputItem(inputItemId: inputItemId) }
    }

    func getInputPublishStatus(inputIds: [String]) async throws -> [String: String] {
        guard network.isConnected else { return [:] }
        let response = try await apiCall { try await self.api.getInputPublishStatus(inputIds: inputIds) }
        var map: [String: String] = [:]
        for (inputId, postId) in response.statuses {
            if let postId { map[inputId] = postId }
        }
        return map
    }

    // MARK: - Generation Settings

    func getGenerationSettings() async throws -> GenerationSettingsResponse {
        guard network.isConnected else {
            throw OfflineError.requiresNetwork("Settings unavailable offline.")
        }
        return try await apiCall { try await self.api.getGenerationSettings() }
    }

    func saveGenerationSettings(_ settings: GenerationSettingsRequest) async throws -> GenerationSettingsResponse {
        guard network.isConnected else {
            throw OfflineError.requiresNetwork("You're offline. Connect to save settings.")
        }
        return try await apiCall { try await self.api.saveGenerationSettings(settings) }
    }

    // MARK: - Export

    func exportDay(date: String) async throws -> ExportResponse {
        guard network.isConnected else {
            throw OfflineError.requiresNetwork("Export unavailable offline.")
        }
        return try await apiCall { try await self.api.exportDay(date: date) }
    }

    // MARK: - Public Feed (with caching for offline)

    func fetchPublicPosts(cursor: String? = nil, limit: Int = 10, channel: String? = nil) async throws -> PublicPostListResponse {
        if network.isConnected {
            do {
                let response = try await apiCall {
                    try await self.api.fetchPublicPosts(cursor: cursor, limit: limit, channel: channel)
                }
                // Cache first page (no cursor) for offline viewing
                if cursor == nil {
                    cache.cacheBlogPosts(response.items, replace: true)
                } else {
                    cache.cacheBlogPosts(response.items, replace: false)
                }
                return response
            } catch {
                // Fallback to cached posts
                let cached = cache.getCachedBlogPosts(channel: channel)
                return PublicPostListResponse(items: cached, cursor: nil, hasMore: false)
            }
        }
        // Offline: return cached posts
        let cached = cache.getCachedBlogPosts(channel: channel)
        return PublicPostListResponse(items: cached, cursor: nil, hasMore: false)
    }

    func fetchPublicPost(slug: String) async throws -> PublishedPostResponse {
        if network.isConnected {
            do {
                let post = try await apiCall { try await self.api.fetchPublicPost(slug: slug) }
                cache.cacheBlogPost(post)
                return post
            } catch {
                // Try cache
                if let cached = cache.getCachedBlogPost(slug: slug) {
                    return cached
                }
                throw error
            }
        }
        // Offline: return from cache
        if let cached = cache.getCachedBlogPost(slug: slug) {
            return cached
        }
        throw OfflineError.requiresNetwork("This post is not available offline.")
    }

    // MARK: - Private

    private func cachedDayResponse(date: String) -> DayResponse {
        let items = cache.getCachedItems(date: date)
        let generations = cache.getCachedGenerations(date: date)
        return DayResponse(date: date, inputItems: items, generations: generations)
    }
}
