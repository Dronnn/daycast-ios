import SwiftUI
import PhotosUI
import UIKit

struct FeedView: View {
    @State private var viewModel = FeedViewModel()
    @State private var showClearConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                feedScrollView
                composerBar
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Today, \(formatFeedDate())")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            showClearConfirmation = true
                        } label: {
                            Label("Clear Day", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .fontWeight(.medium)
                    }
                }
            }
            .confirmationDialog(
                "Clear all items for today?",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear Day", role: .destructive) {
                    Task { await viewModel.clearDay() }
                }
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(item: $viewModel.editingItemId) { _ in
                editSheet
            }
        }
    }

    // MARK: - Feed Scroll View

    private var feedScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView()
                        .padding(.top, 40)
                } else if viewModel.items.isEmpty && !viewModel.isLoading {
                    emptyState
                } else {
                    ForEach(viewModel.items) { item in
                        itemRow(item)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .defaultScrollAnchor(.bottom)
        .refreshable {
            await viewModel.fetchItems()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 60)
            Image(systemName: "text.bubble")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("No items yet")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            Text("Add your first thought, link, or photo")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Item Row

    private func itemRow(_ item: InputItem) -> some View {
        HStack {
            Spacer(minLength: 60)
            VStack(alignment: .trailing, spacing: 4) {
                itemBubble(item)
                    .contextMenu {
                        if item.type == .text || item.type == .url {
                            Button {
                                viewModel.startEditing(item)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
                        Button {
                            UIPasteboard.general.string = item.content
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        Button(role: .destructive) {
                            Task { await viewModel.deleteItem(item) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }

                Text(formatTime(item.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.trailing, 4)
            }
        }
    }

    // MARK: - Item Bubble

    @ViewBuilder
    private func itemBubble(_ item: InputItem) -> some View {
        switch item.type {
        case .text:
            textBubble(item)
        case .url:
            urlCard(item)
        case .image:
            imageBubble(item)
        }
    }

    // MARK: - Text Bubble

    private func textBubble(_ item: InputItem) -> some View {
        Text(item.content)
            .font(.body)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.dcBlue, in: RoundedRectangle(cornerRadius: 18))
            .textSelection(.enabled)
    }

    // MARK: - URL Card

    private func urlCard(_ item: InputItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Domain label
            HStack(spacing: 4) {
                Image(systemName: "link")
                    .font(.caption2)
                Text(getDomain(item.content))
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.white.opacity(0.8))

            // URL text
            Text(item.content)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .truncationMode(.middle)

            // Extracted text preview
            if let extracted = item.extractedText, !extracted.isEmpty {
                Divider()
                    .background(.white.opacity(0.3))
                Text(extracted)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(3)
            }
        }
        .padding(12)
        .frame(maxWidth: 280, alignment: .leading)
        .background(Color.dcBlue, in: RoundedRectangle(cornerRadius: 16))
        .textSelection(.enabled)
        .onTapGesture {
            if let url = URL(string: item.content) {
                openURL(url)
            }
        }
    }

    // MARK: - Image Bubble

    private func imageBubble(_ item: InputItem) -> some View {
        Group {
            if let url = APIService.shared.imageURL(path: item.content) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure:
                        imagePlaceholder(systemName: "exclamationmark.triangle", text: "Failed to load")
                    case .empty:
                        ProgressView()
                            .frame(width: 200, height: 150)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                imagePlaceholder(systemName: "photo", text: "Image")
            }
        }
        .frame(maxWidth: 240)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func imagePlaceholder(systemName: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemName)
                .font(.title2)
            Text(text)
                .font(.caption)
        }
        .foregroundStyle(.secondary)
        .frame(width: 200, height: 150)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Composer Bar

    private var composerBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                // Photo picker
                PhotosPicker(
                    selection: $viewModel.selectedPhoto,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.dcBlue)
                }
                .onChange(of: viewModel.selectedPhoto) { _, newValue in
                    if let newValue {
                        Task {
                            await viewModel.uploadImage(from: newValue)
                            viewModel.selectedPhoto = nil
                        }
                    }
                }

                // Text field
                TextField("Add a thought, link, or note...", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.tertiarySystemFill), in: Capsule())
                    .onSubmit {
                        Task { await viewModel.sendItem() }
                    }

                // Send button
                Button {
                    Task { await viewModel.sendItem() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(sendButtonDisabled ? Color(.tertiaryLabel) : Color.dcBlue)
                }
                .disabled(sendButtonDisabled)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }

    private var sendButtonDisabled: Bool {
        viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending
    }

    // MARK: - Edit Sheet

    private var editSheet: some View {
        NavigationStack {
            Form {
                TextField("Content", text: $viewModel.editText, axis: .vertical)
                    .lineLimit(3...10)
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.cancelEditing()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await viewModel.saveEdit() }
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    @Environment(\.openURL) private var openURL
}

// MARK: - Make editingItemId work with .sheet(item:)

extension String: @retroactive Identifiable {
    public var id: String { self }
}

#Preview {
    FeedView()
}
