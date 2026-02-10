import UIKit

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
        do {
            let response = try await APIService.shared.fetchDay(date: todayISO())
            items = response.inputItems
            generations = response.generations
            if !generations.isEmpty {
                currentGenIndex = generations.count - 1
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func generate() async {
        isGenerating = true
        error = nil
        do {
            let generation = try await APIService.shared.generate(date: todayISO())
            generations.append(generation)
            currentGenIndex = generations.count - 1
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
            let generation = try await APIService.shared.regenerate(generationId: current.id)
            generations.append(generation)
            currentGenIndex = generations.count - 1
        } catch {
            self.error = error.localizedDescription
        }
        isGenerating = false
    }

    func regenerateChannel(_ channelId: String) async {
        guard let current = currentGeneration else { return }
        error = nil
        do {
            let generation = try await APIService.shared.regenerate(
                generationId: current.id,
                channels: [channelId]
            )
            generations.append(generation)
            currentGenIndex = generations.count - 1
        } catch {
            self.error = error.localizedDescription
        }
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
