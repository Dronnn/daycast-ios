import SwiftUI

struct HistoryDetailView: View {
    @State private var viewModel: HistoryDetailViewModel

    init(date: String) {
        _viewModel = State(initialValue: HistoryDetailViewModel(date: date))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.day == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage, viewModel.day == nil {
                ContentUnavailableView {
                    Label("Unable to Load", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        Task { await viewModel.fetchDay() }
                    }
                }
            } else {
                contentList
            }
        }
        .navigationTitle(formatFullDate(viewModel.date))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.fetchDay()
        }
    }

    // MARK: - Content List

    private var contentList: some View {
        List {
            messagesSection
            generationsSection
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Messages Section

    @ViewBuilder
    private var messagesSection: some View {
        let items = viewModel.inputItems
        if !items.isEmpty {
            Section {
                ForEach(items) { item in
                    InputItemRow(item: item, viewModel: viewModel)
                }
            } header: {
                sectionHeader(title: "Messages", count: items.count)
            }
        }
    }

    // MARK: - Generations Section

    @ViewBuilder
    private var generationsSection: some View {
        let gens = viewModel.generations
        if !gens.isEmpty {
            Section {
                ForEach(Array(gens.enumerated()), id: \.element.id) { index, generation in
                    GenerationRow(
                        generation: generation,
                        number: index + 1,
                        viewModel: viewModel
                    )
                }
            } header: {
                sectionHeader(title: "Generations", count: gens.count)
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, count: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(count)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.quaternary)
                .clipShape(Capsule())
        }
        .font(.subheadline)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
        .textCase(nil)
    }
}

// MARK: - Input Item Row

private struct InputItemRow: View {
    let item: InputItem
    let viewModel: HistoryDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Content based on type
            switch item.type {
            case .text:
                textContent
            case .url:
                urlContent
            case .image:
                imageContent
            }

            // Bottom row: time + badges
            HStack(spacing: 8) {
                Text(formatTime(item.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                if item.cleared {
                    badge("Deleted", color: .dcRed)
                }

                if let edits = item.edits, !edits.isEmpty {
                    Button {
                        viewModel.toggleEditHistory(for: item.id)
                    } label: {
                        badge("Edited", color: .dcBlue)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Expandable edit history
            if let edits = item.edits, !edits.isEmpty,
               viewModel.isEditHistoryExpanded(for: item.id) {
                editHistoryView(edits: edits)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Text Content

    private var textContent: some View {
        Text(item.content)
            .font(.body)
            .lineLimit(6)
    }

    // MARK: - URL Content

    private var urlContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundStyle(Color.dcBlue)
                Text(getDomain(item.content))
                    .font(.caption)
                    .foregroundStyle(Color.dcBlue)
            }

            if let url = URL(string: item.content) {
                Link(destination: url) {
                    Text(item.content)
                        .font(.footnote)
                        .foregroundStyle(Color.dcBlue)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            } else {
                Text(item.content)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let extracted = item.extractedText, !extracted.isEmpty {
                Text(extracted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Image Content

    private var imageContent: some View {
        Group {
            if let imageURL = APIService.shared.imageURL(path: item.content) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .failure:
                        Label("Failed to load image", systemImage: "photo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .empty:
                        ProgressView()
                            .frame(height: 100)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Label(item.content, systemImage: "photo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Badge

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: - Edit History

    private func editHistoryView(edits: [InputItemEdit]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(edits) { edit in
                HStack(alignment: .top, spacing: 8) {
                    Rectangle()
                        .fill(Color.dcBlue.opacity(0.3))
                        .frame(width: 2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(edit.oldContent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)

                        Text(formatTime(edit.editedAt))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.leading, 8)
        .padding(.top, 4)
    }
}

// MARK: - Generation Row

private struct GenerationRow: View {
    let generation: Generation
    let number: Int
    let viewModel: HistoryDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Generation #\(number)")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Text(formatTime(generation.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Result cards
            ForEach(generation.results) { result in
                GenerationResultCard(result: result, viewModel: viewModel)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Generation Result Card

private struct GenerationResultCard: View {
    let result: GenerationResult
    let viewModel: HistoryDetailViewModel

    private var channel: ChannelMeta {
        ChannelMeta.find(result.channelId)
    }

    private var isCopied: Bool {
        viewModel.copiedResultId == result.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Channel header
            HStack(spacing: 8) {
                ChannelIconView(channel: channel, size: 28)

                VStack(alignment: .leading, spacing: 0) {
                    Text(channel.name)
                        .font(.footnote)
                        .fontWeight(.semibold)

                    Text("\(result.style.capitalized) \u{00B7} \(result.language.uppercased())")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    viewModel.copyText(result.text, resultId: result.id)
                } label: {
                    Label(
                        isCopied ? "Copied" : "Copy",
                        systemImage: isCopied ? "checkmark" : "doc.on.doc"
                    )
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isCopied ? Color.dcGreen : Color.dcBlue)
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.2), value: isCopied)
            }

            // Text content
            Text(result.text)
                .font(.footnote)
                .lineLimit(8)
                .foregroundStyle(.primary)

            // Publish controls
            HStack(spacing: 8) {
                if let postId = viewModel.publishStatus[result.id] as? String {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Published")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(Color.dcGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.dcGreen.opacity(0.1))
                    .clipShape(Capsule())

                    Button {
                        Task { await viewModel.unpublishPost(resultId: result.id) }
                    } label: {
                        Text("Unpublish")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        Task { await viewModel.publishPost(resultId: result.id) }
                    } label: {
                        Label("Publish", systemImage: "arrow.up.circle.fill")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.dcGreen)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isPublishing)
                }

                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    NavigationStack {
        HistoryDetailView(date: "2026-02-10")
    }
}
