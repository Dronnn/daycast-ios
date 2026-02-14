import SwiftUI

struct HistoryView: View {
    @State private var viewModel = HistoryViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.days.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage, viewModel.days.isEmpty {
                    ContentUnavailableView {
                        Label("Unable to Load", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") {
                            Task { await viewModel.fetchDays() }
                        }
                        .buttonStyle(.dcScale)
                    }
                } else if viewModel.days.isEmpty {
                    ContentUnavailableView {
                        Label("No History", systemImage: "clock")
                    } description: {
                        Text("Your past days will appear here.")
                    }
                } else {
                    daysList
                }
            }
            .navigationTitle("History")
            .searchable(text: $viewModel.searchText, prompt: "Search days...")
            .onChange(of: viewModel.searchText) {
                viewModel.searchChanged()
            }
            .refreshable {
                await viewModel.fetchDays()
            }
        }
    }

    // MARK: - Days List

    private var daysList: some View {
        List {
            ForEach(Array(viewModel.groupedDays.enumerated()), id: \.element.month) { groupIndex, group in
                Section {
                    ForEach(Array(group.days.enumerated()), id: \.element.id) { dayIndex, day in
                        NavigationLink(value: day) {
                            DayRow(day: day)
                        }
                        .dcScrollReveal(index: groupIndex * 10 + dayIndex)
                    }
                } header: {
                    Text(group.month)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: DaySummary.self) { day in
            HistoryDetailView(date: day.date)
        }
    }
}

// MARK: - Day Row

private struct DayRow: View {
    let day: DaySummary

    var body: some View {
        HStack(spacing: 12) {
            // Status dot
            Circle()
                .fill(day.generationCount > 0 ? Color.dcGreen : Color.gray.opacity(0.4))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(formatHistoryDate(day.date))
                    .font(.body)
                    .fontWeight(.medium)

                Text(statsLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var statsLabel: String {
        var parts: [String] = []
        let itemWord = day.inputCount == 1 ? "item" : "items"
        parts.append("\(day.inputCount) \(itemWord)")
        if day.generationCount > 0 {
            let genWord = day.generationCount == 1 ? "gen" : "gens"
            parts.append("\(day.generationCount) \(genWord)")
        }
        return parts.joined(separator: " \u{00B7} ")
    }
}


#Preview {
    HistoryView()
}
