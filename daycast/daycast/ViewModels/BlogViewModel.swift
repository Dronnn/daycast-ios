import SwiftUI

@Observable
class BlogViewModel {

    // MARK: - State

    var posts: [PublishedPostResponse] = []
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?

    // Pagination
    var cursor: String?
    var hasMore = true

    // Filter
    var selectedChannel: String?

    // MARK: - Init

    private let api = APIService.shared

    init() {
        Task { await fetchPosts() }
    }

    // MARK: - Fetch

    func fetchPosts() async {
        isLoading = true
        errorMessage = nil
        cursor = nil
        hasMore = true
        do {
            let response = try await api.fetchPublicPosts(channel: selectedChannel)
            posts = response.items
            cursor = response.cursor
            hasMore = response.hasMore
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Load More

    func loadMore() async {
        guard !isLoadingMore, hasMore, let cursor else { return }
        isLoadingMore = true
        do {
            let response = try await api.fetchPublicPosts(cursor: cursor, channel: selectedChannel)
            posts.append(contentsOf: response.items)
            self.cursor = response.cursor
            hasMore = response.hasMore
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingMore = false
    }

    // MARK: - Channel Filter

    func selectChannel(_ channel: String?) {
        selectedChannel = channel
        Task { await fetchPosts() }
    }
}
