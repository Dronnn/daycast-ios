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
