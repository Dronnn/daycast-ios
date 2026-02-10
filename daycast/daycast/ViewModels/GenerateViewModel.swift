import UIKit
import Observation

@Observable
class GenerateViewModel {
    var items: [InputItem] = []
    var generations: [Generation] = []
    var currentGenIndex: Int = 0
    var isLoading: Bool = false
    var isGenerating: Bool = false
    var showSource: Bool = false
    var error: String?
    var copiedResultId: String?
    var publishStatus: [String: String?] = [:]
    var isPublishing: Bool = false

    private let repo = DataRepository.shared

    var currentGeneration: Generation? {
        guard !generations.isEmpty, currentGenIndex >= 0, currentGenIndex < generations.count else {
            return nil
        }
        return generations[currentGenIndex]
    }

    var activeItemCount: Int {
        items.filter { !$0.cleared }.count
    }

    var hasGenerations: Bool {
        !generations.isEmpty
    }

    var canGoBack: Bool {
        currentGenIndex > 0
    }

    var canGoForward: Bool {
        currentGenIndex < generations.count - 1
    }

    init() {
        Task {
            await fetchDay()
        }
    }

    func fetchDay() async {
        isLoading = true
        error = nil
        let response = await repo.fetchDay(date: todayISO())
        items = response.inputItems
        generations = response.generations
        if !generations.isEmpty {
            currentGenIndex = generations.count - 1
        }
        await loadPublishStatus()
        isLoading = false
    }

    func generate() async {
        isGenerating = true
        error = nil
        do {
            let generation = try await repo.generate(date: todayISO())
            generations.append(generation)
            currentGenIndex = generations.count - 1
            await loadPublishStatus()
        } catch let offlineError as OfflineError {
            self.error = offlineError.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }
        isGenerating = false
    }

    func regenerateAll() async {
        guard let current = currentGeneration else { return }
        isGenerating = true
        error = nil
        do {
            let generation = try await repo.regenerate(generationId: current.id, date: todayISO())
            generations.append(generation)
            currentGenIndex = generations.count - 1
            await loadPublishStatus()
        } catch let offlineError as OfflineError {
            self.error = offlineError.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }
        isGenerating = false
    }

    func regenerateChannel(_ channelId: String) async {
        guard let current = currentGeneration else { return }
        error = nil
        do {
            let generation = try await repo.regenerate(
                generationId: current.id,
                channels: [channelId],
                date: todayISO()
            )
            generations.append(generation)
            currentGenIndex = generations.count - 1
            await loadPublishStatus()
        } catch let offlineError as OfflineError {
            self.error = offlineError.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadPublishStatus() async {
        guard let gen = currentGeneration else { return }
        let ids = gen.results.map { $0.id }
        guard !ids.isEmpty else { return }
        do {
            let response = try await repo.getPublishStatus(resultIds: ids)
            publishStatus = response.statuses
        } catch {
            // silently fail (offline or network error)
        }
    }

    func publishPost(resultId: String) async {
        isPublishing = true
        do {
            let post = try await repo.publishPost(resultId: resultId)
            publishStatus[resultId] = post.id
        } catch let offlineError as OfflineError {
            self.error = offlineError.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }
        isPublishing = false
    }

    func unpublishPost(resultId: String) async {
        guard let postId = publishStatus[resultId] as? String else { return }
        isPublishing = true
        do {
            try await repo.unpublishPost(postId: postId)
            publishStatus[resultId] = nil
        } catch let offlineError as OfflineError {
            self.error = offlineError.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }
        isPublishing = false
    }

    func goToPreviousGeneration() {
        if canGoBack {
            currentGenIndex -= 1
        }
    }

    func goToNextGeneration() {
        if canGoForward {
            currentGenIndex += 1
        }
    }

    func copyText(_ text: String, resultId: String) {
        UIPasteboard.general.string = text
        copiedResultId = resultId
        Task {
            try? await Task.sleep(for: .seconds(2))
            if copiedResultId == resultId {
                copiedResultId = nil
            }
        }
    }
}
