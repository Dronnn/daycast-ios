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

    // Photo picker
    var selectedPhoto: PhotosPickerItem?
    var isUploadingImage = false

    // MARK: - Init

    private let api = APIService.shared

    init() {
        Task { await fetchItems() }
    }

    // MARK: - Fetch

    func fetchItems() async {
        isLoading = true
        errorMessage = nil
        do {
            items = try await api.fetchItems(date: todayISO())
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Send

    func sendItem() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let type: InputItemType = trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")
            ? .url : .text

        let request = InputItemCreateRequest(type: type, content: trimmed, date: todayISO())

        isSending = true
        do {
            let newItem = try await api.createItem(request)
            items.append(newItem)
            inputText = ""
        } catch {
            errorMessage = error.localizedDescription
        }
        isSending = false
    }

    // MARK: - Delete

    func deleteItem(_ item: InputItem) async {
        do {
            try await api.deleteItem(id: item.id)
            items.removeAll { $0.id == item.id }
        } catch {
            errorMessage = error.localizedDescription
        }
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

        do {
            let updated = try await api.updateItem(id: id, content: trimmed)
            if let index = items.firstIndex(where: { $0.id == id }) {
                items[index] = updated
            }
            cancelEditing()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Clear Day

    func clearDay() async {
        do {
            try await api.clearDay(date: todayISO())
            items.removeAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Image Upload

    func uploadImage(from photoItem: PhotosPickerItem) async {
        isUploadingImage = true
        defer { isUploadingImage = false }

        do {
            guard let data = try await photoItem.loadTransferable(type: Data.self) else { return }
            let filename = "photo_\(Int(Date().timeIntervalSince1970)).jpg"
            let newItem = try await api.uploadImage(imageData: data, date: todayISO(), filename: filename)
            items.append(newItem)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
