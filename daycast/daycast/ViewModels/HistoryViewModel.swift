import UIKit

// MARK: - History List ViewModel

@Observable
class HistoryViewModel {

    var days: [DaySummary] = []
    var searchText = ""
    var isLoading = false
    var errorMessage: String?

    private let api = APIService.shared
    private var searchTask: Task<Void, Never>?

    /// Groups days by month/year label for section headers.
    var groupedDays: [(month: String, days: [DaySummary])] {
        let grouped = Dictionary(grouping: days) { monthYearLabel($0.date) }
        // Sort groups by the first date in each group (descending)
        return grouped
            .sorted { lhs, rhs in
                let lhsDate = lhs.value.first?.date ?? ""
                let rhsDate = rhs.value.first?.date ?? ""
                return lhsDate > rhsDate
            }
            .map { (month: $0.key, days: $0.value) }
    }

    init() {
        Task { await fetchDays() }
    }

    func fetchDays() async {
        isLoading = true
        errorMessage = nil
        do {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let response = try await api.fetchDays(search: query.isEmpty ? nil : query)
            days = response.items
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func searchChanged() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await fetchDays()
        }
    }
}

// MARK: - History Detail ViewModel

@Observable
class HistoryDetailViewModel {

    let date: String
    var day: DayResponse?
    var isLoading = false
    var errorMessage: String?
    var copiedResultId: String?
    var expandedEditItemIds: Set<String> = []

    private let api = APIService.shared

    init(date: String) {
        self.date = date
        Task { await fetchDay() }
    }

    func fetchDay() async {
        isLoading = true
        errorMessage = nil
        do {
            day = try await api.fetchDay(date: date)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    var inputItems: [InputItem] {
        day?.inputItems ?? []
    }

    var generations: [Generation] {
        day?.generations ?? []
    }

    func toggleEditHistory(for itemId: String) {
        if expandedEditItemIds.contains(itemId) {
            expandedEditItemIds.remove(itemId)
        } else {
            expandedEditItemIds.insert(itemId)
        }
    }

    func isEditHistoryExpanded(for itemId: String) -> Bool {
        expandedEditItemIds.contains(itemId)
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
