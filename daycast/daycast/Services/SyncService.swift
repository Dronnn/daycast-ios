import Foundation
import SwiftData

enum OfflineError: LocalizedError {
    case requiresNetwork(String)

    var errorDescription: String? {
        switch self {
        case .requiresNetwork(let msg): msg
        }
    }
}

@MainActor
@Observable
final class SyncService {
    static let shared = SyncService()

    var isSyncing = false
    var authError = false

    var modelContext: ModelContext?

    private let api = APIService.shared
    private let cache = CacheService.shared
    private var isObserving = false

    private init() {}

    func configure(with container: ModelContainer) {
        self.modelContext = container.mainContext
    }

    // MARK: - Enqueue Operations

    func enqueueCreate(type: InputItemType, content: String, date: String, tempId: String) {
        guard let ctx = modelContext else { return }
        let payload = try? JSONEncoder().encode(["type": type.rawValue, "content": content, "date": date])
        let op = PendingSyncOperation(
            operationType: "create",
            entityType: "inputItem",
            entityId: tempId,
            payload: payload,
            date: date
        )
        ctx.insert(op)
        trySave(ctx)
    }

    func enqueueUpdate(id: String, content: String) {
        guard let ctx = modelContext else { return }
        let payload = try? JSONEncoder().encode(["content": content])
        let op = PendingSyncOperation(
            operationType: "update",
            entityType: "inputItem",
            entityId: id,
            payload: payload
        )
        ctx.insert(op)
        trySave(ctx)
    }

    func enqueueDelete(id: String) {
        guard let ctx = modelContext else { return }
        // Remove any pending updates for the same ID
        let predicate = #Predicate<PendingSyncOperation> {
            $0.entityId == id && ($0.operationType == "update" || $0.operationType == "create" || $0.operationType == "updateFields")
        }
        if let existing = try? ctx.fetch(FetchDescriptor(predicate: predicate)) {
            for op in existing { ctx.delete(op) }
        }
        // If ID is temp (local-only create that hasn't synced), no need to enqueue delete
        if id.hasPrefix("temp_") {
            trySave(ctx)
            return
        }
        let op = PendingSyncOperation(
            operationType: "delete",
            entityType: "inputItem",
            entityId: id
        )
        ctx.insert(op)
        trySave(ctx)
    }

    func enqueueClearDay(date: String) {
        guard let ctx = modelContext else { return }
        // Remove any pending item operations for this date
        let predicate = #Predicate<PendingSyncOperation> {
            $0.date == date && $0.entityType == "inputItem"
        }
        if let existing = try? ctx.fetch(FetchDescriptor(predicate: predicate)) {
            for op in existing { ctx.delete(op) }
        }
        let op = PendingSyncOperation(
            operationType: "clearDay",
            entityType: "inputItem",
            entityId: "",
            date: date
        )
        ctx.insert(op)
        trySave(ctx)
    }

    func enqueueUploadImage(imageData: Data, date: String, filename: String, tempId: String) {
        guard let ctx = modelContext else { return }
        // Save image to Documents dir
        let filePath = saveImageToDocuments(data: imageData, filename: "\(tempId)_\(filename)")
        let payload = try? JSONEncoder().encode(["date": date, "filename": filename])
        let op = PendingSyncOperation(
            operationType: "uploadImage",
            entityType: "inputItem",
            entityId: tempId,
            payload: payload,
            imageFilePath: filePath,
            date: date
        )
        ctx.insert(op)
        trySave(ctx)
    }

    func enqueueUpdateFields(id: String, importance: Int? = nil, includeInGeneration: Bool? = nil) {
        guard let ctx = modelContext else { return }
        let predicate = #Predicate<PendingSyncOperation> {
            $0.entityId == id && $0.operationType == "updateFields"
        }
        // Start with existing payload values to preserve previously queued fields
        var dict: [String: String] = [:]
        if let existing = try? ctx.fetch(FetchDescriptor(predicate: predicate)) {
            if let first = existing.first,
               let payload = first.payload,
               let oldDict = try? JSONDecoder().decode([String: String].self, from: payload) {
                dict = oldDict
            }
            for op in existing { ctx.delete(op) }
        }
        // Merge new values (overwriting old if present)
        if let importance {
            dict["importance"] = String(importance)
        }
        if let includeInGeneration {
            dict["includeInGeneration"] = String(includeInGeneration)
        }
        let payload = try? JSONEncoder().encode(dict)
        let op = PendingSyncOperation(
            operationType: "updateFields",
            entityType: "inputItem",
            entityId: id,
            payload: payload
        )
        ctx.insert(op)
        trySave(ctx)
    }

    func enqueueSaveChannelSettings(_ settings: [ChannelSetting]) {
        guard let ctx = modelContext else { return }
        // Remove any previous channel settings operations
        let predicate = #Predicate<PendingSyncOperation> {
            $0.entityType == "channelSettings"
        }
        if let existing = try? ctx.fetch(FetchDescriptor(predicate: predicate)) {
            for op in existing { ctx.delete(op) }
        }
        let payload = try? JSONEncoder().encode(SaveChannelSettingsRequest(channels: settings))
        let op = PendingSyncOperation(
            operationType: "saveChannelSettings",
            entityType: "channelSettings",
            entityId: ""
        )
        op.payload = payload
        ctx.insert(op)
        trySave(ctx)
    }

    // MARK: - Process Queue

    func processQueue() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        guard let ctx = modelContext else { return }

        let descriptor = FetchDescriptor<PendingSyncOperation>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        guard let operations = try? ctx.fetch(descriptor), !operations.isEmpty else { return }

        for op in operations {
            // Skip update/delete/updateFields for temp IDs whose create hasn't synced yet
            if (op.operationType == "update" || op.operationType == "delete" || op.operationType == "updateFields"),
               op.entityId.hasPrefix("temp_") {
                continue
            }

            do {
                try await processOperation(op)
                ctx.delete(op)
                trySave(ctx)
            } catch let error as APIServiceError where error == .unauthorized {
                authError = true
                break
            } catch {
                op.retryCount += 1
                op.lastError = error.localizedDescription
                trySave(ctx)
                if op.retryCount >= 5 {
                    ctx.delete(op)
                    trySave(ctx)
                }
            }
        }
    }

    // MARK: - Connectivity Observation

    func startObservingConnectivity() {
        guard !isObserving else { return }
        isObserving = true

        Task {
            var wasConnected = NetworkMonitor.shared.isConnected
            while true {
                try? await Task.sleep(for: .seconds(2))
                let nowConnected = NetworkMonitor.shared.isConnected
                if !wasConnected && nowConnected {
                    await processQueue()
                }
                wasConnected = nowConnected
            }
        }
    }

    // MARK: - Private

    private func processOperation(_ op: PendingSyncOperation) async throws {
        switch op.operationType {
        case "create":
            guard let payload = op.payload,
                  let dict = try? JSONDecoder().decode([String: String].self, from: payload),
                  let typeStr = dict["type"],
                  let type = InputItemType(rawValue: typeStr),
                  let content = dict["content"],
                  let date = dict["date"] else { return }

            let request = InputItemCreateRequest(type: type, content: content, date: date)
            let serverItem = try await api.createItem(request)
            cache.remapItemId(tempId: op.entityId, serverId: serverItem.id)
            // Remap ID in any pending operations referencing the temp ID
            remapPendingOperations(tempId: op.entityId, serverId: serverItem.id)

        case "update":
            guard let payload = op.payload,
                  let dict = try? JSONDecoder().decode([String: String].self, from: payload),
                  let content = dict["content"] else { return }
            let updated = try await api.updateItem(id: op.entityId, content: content)
            if shouldAcceptServerVersion(entityId: op.entityId, serverUpdatedAt: updated.updatedAt) {
                cache.cacheItem(updated)
            }

        case "delete":
            try await api.deleteItem(id: op.entityId)

        case "clearDay":
            try await api.clearDay(date: op.date)

        case "uploadImage":
            guard let filePath = op.imageFilePath,
                  let imageData = loadImageFromDocuments(filePath: filePath),
                  let payload = op.payload,
                  let dict = try? JSONDecoder().decode([String: String].self, from: payload),
                  let date = dict["date"],
                  let filename = dict["filename"] else { return }

            let serverItem = try await api.uploadImage(imageData: imageData, date: date, filename: filename)
            cache.remapItemId(tempId: op.entityId, serverId: serverItem.id)
            remapPendingOperations(tempId: op.entityId, serverId: serverItem.id)
            deleteImageFromDocuments(filePath: filePath)

        case "updateFields":
            guard let payload = op.payload,
                  let dict = try? JSONDecoder().decode([String: String].self, from: payload) else { return }
            let importance = dict["importance"].flatMap { Int($0) }
            let includeInGeneration = dict["includeInGeneration"].flatMap { Bool($0) }
            let updated = try await api.updateItemFields(
                id: op.entityId,
                importance: importance,
                includeInGeneration: includeInGeneration
            )
            if shouldAcceptServerVersion(entityId: op.entityId, serverUpdatedAt: updated.updatedAt) {
                cache.cacheItem(updated)
            }

        case "saveChannelSettings":
            guard let payload = op.payload,
                  let request = try? JSONDecoder().decode(SaveChannelSettingsRequest.self, from: payload) else { return }
            try await api.saveChannelSettings(request.channels)

        default:
            break
        }
    }

    private func remapPendingOperations(tempId: String, serverId: String) {
        guard let ctx = modelContext else { return }
        let predicate = #Predicate<PendingSyncOperation> { $0.entityId == tempId }
        if let ops = try? ctx.fetch(FetchDescriptor(predicate: predicate)) {
            for op in ops {
                op.entityId = serverId
            }
            trySave(ctx)
        }
    }

    // MARK: - Conflict Resolution

    private func shouldAcceptServerVersion(entityId: String, serverUpdatedAt: String) -> Bool {
        guard let ctx = cache.modelContext else { return true }
        let predicate = #Predicate<CachedInputItem> { $0.itemId == entityId }
        guard let cached = try? ctx.fetch(FetchDescriptor(predicate: predicate)).first else {
            return true // No local version, accept server
        }
        return serverUpdatedAt >= cached.updatedAt
    }

    // MARK: - Image File Helpers

    private func saveImageToDocuments(data: Data, filename: String) -> String {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = dir.appendingPathComponent("pending_images", isDirectory: true).appendingPathComponent(filename)
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL)
        return fileURL.path
    }

    private func loadImageFromDocuments(filePath: String) -> Data? {
        try? Data(contentsOf: URL(fileURLWithPath: filePath))
    }

    private func deleteImageFromDocuments(filePath: String) {
        try? FileManager.default.removeItem(atPath: filePath)
    }

    private func trySave(_ context: ModelContext) {
        try? context.save()
    }
}

// MARK: - APIServiceError Equatable (for pattern matching)

extension APIServiceError: Equatable {
    static func == (lhs: APIServiceError, rhs: APIServiceError) -> Bool {
        switch (lhs, rhs) {
        case (.unauthorized, .unauthorized): true
        case (.invalidURL, .invalidURL): true
        default: false
        }
    }
}
