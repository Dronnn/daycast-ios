import SwiftUI
import PhotosUI

@Observable
class FeedViewModel {

    // MARK: - State

    var items: [InputItem] = []
    var inputText = ""
    var isLoading = false
    var isSending = false
    var errorMessage: String?
    var toastMessage: String?
    var publishedMap: [String: String] = [:] // input_item_id -> post_id

    // Editing
    var editingItemId: String?
    var editText = ""

    // Photo picker / camera
    var selectedPhoto: PhotosPickerItem?
    var isUploadingImage = false
    var showCamera = false

    // MARK: - Init

    private let repo = DataRepository.shared

    init() {
        Task { await fetchItems() }
    }

    // MARK: - Fetch

    func fetchItems() async {
        isLoading = true
        errorMessage = nil
        items = await repo.fetchItems(date: todayISO())
        NotificationManager.shared.updateTodayNotification(itemCount: items.count)
        isLoading = false
        await loadPublishStatus()
    }

    private func loadPublishStatus() async {
        let textIds = items.filter { $0.type == .text }.map(\.id)
        guard !textIds.isEmpty else { return }
        do {
            publishedMap = try await repo.getInputPublishStatus(inputIds: textIds)
        } catch {}
    }

    // MARK: - Send

    func sendItem() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let type: InputItemType = trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")
            ? .url : .text

        isSending = true
        let newItem = await repo.createItem(type: type, content: trimmed, date: todayISO())
        items.append(newItem)
        NotificationManager.shared.updateTodayNotification(itemCount: items.count)
        inputText = ""
        isSending = false
    }

    // MARK: - Delete

    func deleteItem(_ item: InputItem) async {
        await repo.deleteItem(id: item.id)
        items.removeAll { $0.id == item.id }
    }

    // MARK: - Edit

    func startEditing(_ item: InputItem) {
        editingItemId = item.id
        editText = item.content
    }

    func cancelEditing() {
        editingItemId = nil
        editText = ""
    }

    func saveEdit() async {
        guard let id = editingItemId else { return }
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        await repo.updateItem(id: id, content: trimmed)
        // Refresh items to reflect the update
        items = await repo.fetchItems(date: todayISO())
        cancelEditing()
    }

    // MARK: - Clear Day

    func clearDay() async {
        await repo.clearDay(date: todayISO())
        items.removeAll()
        NotificationManager.shared.updateTodayNotification(itemCount: 0)
    }

    // MARK: - Image Upload

    func uploadImage(from photoItem: PhotosPickerItem) async {
        isUploadingImage = true
        defer { isUploadingImage = false }

        do {
            guard let data = try await photoItem.loadTransferable(type: Data.self) else { return }
            let filename = "photo_\(Int(Date().timeIntervalSince1970)).jpg"
            let newItem = try await repo.uploadImage(imageData: data, date: todayISO(), filename: filename)
            items.append(newItem)
            NotificationManager.shared.updateTodayNotification(itemCount: items.count)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Item Fields

    func setImportance(itemId: String, importance: Int?) async {
        let snapshot = items
        // Optimistic local update
        if let index = items.firstIndex(where: { $0.id == itemId }) {
            let old = items[index]
            items[index] = InputItem(
                id: old.id, type: old.type, content: old.content,
                extractedText: old.extractedText, extractError: old.extractError,
                date: old.date, cleared: old.cleared,
                createdAt: old.createdAt, updatedAt: old.updatedAt,
                edits: old.edits, importance: importance,
                includeInGeneration: old.includeInGeneration
            )
        }
        do {
            try await repo.updateItemImportance(id: itemId, importance: importance)
        } catch {
            items = snapshot
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }

    func toggleIncludeInGeneration(itemId: String, include: Bool) async {
        let snapshot = items
        // Optimistic local update
        if let index = items.firstIndex(where: { $0.id == itemId }) {
            let old = items[index]
            items[index] = InputItem(
                id: old.id, type: old.type, content: old.content,
                extractedText: old.extractedText, extractError: old.extractError,
                date: old.date, cleared: old.cleared,
                createdAt: old.createdAt, updatedAt: old.updatedAt,
                edits: old.edits, importance: old.importance,
                includeInGeneration: include
            )
        }
        do {
            try await repo.updateItemIncludeInGeneration(id: itemId, include: include)
        } catch {
            items = snapshot
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }

    func togglePublish(itemId: String) async {
        if let postId = publishedMap[itemId] {
            // Unpublish
            do {
                try await repo.unpublishPost(postId: postId)
                publishedMap.removeValue(forKey: itemId)
                toastMessage = "Unpublished"
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        } else {
            // Publish
            do {
                let post = try await repo.publishInputItem(inputItemId: itemId)
                publishedMap[itemId] = post.id
                toastMessage = "Published!"
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }
        try? await Task.sleep(for: .seconds(2))
        if toastMessage == "Published!" || toastMessage == "Unpublished" { toastMessage = nil }
    }

    func exportDay() async throws -> String {
        let result = try await repo.exportDay(date: todayISO())
        return result.text
    }

    // MARK: - Camera Upload

    func uploadCameraImage(_ image: UIImage) async {
        isUploadingImage = true
        defer { isUploadingImage = false }

        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let filename = "camera_\(Int(Date().timeIntervalSince1970)).jpg"
        do {
            let newItem = try await repo.uploadImage(imageData: data, date: todayISO(), filename: filename)
            items.append(newItem)
            NotificationManager.shared.updateTodayNotification(itemCount: items.count)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
