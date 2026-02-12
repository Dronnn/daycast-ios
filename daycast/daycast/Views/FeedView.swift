import SwiftUI
import PhotosUI
import UIKit

// MARK: - Star Rating View

struct StarRatingView: View {
    let rating: Int?
    let onRate: (Int?) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { n in
                Button {
                    onRate(rating == n ? nil : n)
                } label: {
                    Image(systemName: (rating ?? 0) >= n ? "star.fill" : "star")
                        .font(.system(size: 12))
                        .foregroundStyle((rating ?? 0) >= n ? .yellow : .gray.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct FeedView: View {
    @State private var viewModel = FeedViewModel()
    @State private var showClearConfirmation = false
    @State private var fullscreenImage: UIImage?
    @State private var expandedEdits: Set<String> = []
    @State private var exportCopied = false
    @FocusState private var isComposerFocused: Bool
    @Environment(\.scenePhase) private var scenePhase

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
                        Button {
                            Task { await handleExport() }
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
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
            .fullScreenCover(isPresented: $viewModel.showCamera) {
                CameraView { image in
                    Task { await viewModel.uploadCameraImage(image) }
                }
                .ignoresSafeArea()
            }
            .fullScreenCover(item: $fullscreenImage) { image in
                FullscreenImageView(image: image) {
                    fullscreenImage = nil
                }
            }
            .overlay(alignment: .bottom) {
                if exportCopied {
                    Text("Exported to clipboard")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.green.gradient, in: Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                        .padding(.bottom, 80)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if let toast = viewModel.toastMessage {
                    Text(toast)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.green.gradient, in: Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                        .padding(.bottom, 80)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: exportCopied)
            .animation(.easeInOut(duration: 0.3), value: viewModel.toastMessage)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await viewModel.fetchItems() }
                }
            }
            .task {
                // Poll server every 15s to sync changes from web
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(15))
                    guard !Task.isCancelled else { break }
                    await viewModel.fetchItems()
                }
            }
        }
    }

    // MARK: - Feed Scroll View

    private var feedScrollView: some View {
        ScrollViewReader { proxy in
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
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture { isComposerFocused = false }
            .refreshable {
                await viewModel.fetchItems()
            }
            .onChange(of: viewModel.items.count) {
                withAnimation {
                    proxy.scrollTo("bottom")
                }
            }
            .onAppear {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
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
                VStack(alignment: .trailing, spacing: 6) {
                    itemBubble(item)

                    // Star rating
                    StarRatingView(rating: item.importance) { newRating in
                        Task { await viewModel.setImportance(itemId: item.id, importance: newRating) }
                    }

                    // Edit history badge + expansion
                    if let edits = item.edits, !edits.isEmpty {
                        Button {
                            withAnimation {
                                if expandedEdits.contains(item.id) {
                                    expandedEdits.remove(item.id)
                                } else {
                                    expandedEdits.insert(item.id)
                                }
                            }
                        } label: {
                            Text("Edited (\(edits.count))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                        .buttonStyle(.plain)

                        if expandedEdits.contains(item.id) {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(edits, id: \.id) { edit in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(edit.oldContent)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(formatTime(edit.editedAt))
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.leading, 8)
                                    .overlay(alignment: .leading) {
                                        Rectangle()
                                            .fill(.secondary.opacity(0.3))
                                            .frame(width: 2)
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
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
                    Button {
                        Task { await viewModel.toggleIncludeInGeneration(itemId: item.id, include: !item.includeInGeneration) }
                    } label: {
                        Label(
                            item.includeInGeneration ? "Exclude from Generation" : "Include in Generation",
                            systemImage: item.includeInGeneration ? "eye.slash" : "eye"
                        )
                    }
                    if item.type == .text {
                        let isPublished = viewModel.publishedMap[item.id] != nil
                        Button(role: isPublished ? .destructive : nil) {
                            Task { await viewModel.togglePublish(itemId: item.id) }
                        } label: {
                            Label(
                                isPublished ? "Unpublish" : "Publish",
                                systemImage: isPublished ? "arrow.down.square" : "arrow.up.right.square"
                            )
                        }
                    }
                    Button(role: .destructive) {
                        Task { await viewModel.deleteItem(item) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }

                HStack(spacing: 4) {
                    if !item.includeInGeneration {
                        Image(systemName: "eye.slash")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if viewModel.publishedMap[item.id] != nil {
                        Text("Published")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green, in: Capsule())
                    }
                    Text(formatTime(item.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
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
            .foregroundStyle(item.includeInGeneration ? .white : Color(.secondaryLabel))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                item.includeInGeneration ? Color.dcBlue : Color(.systemGray5),
                in: RoundedRectangle(cornerRadius: 18)
            )
            .textSelection(.enabled)
    }

    // MARK: - URL Card

    private func urlCard(_ item: InputItem) -> some View {
        let url = item.content.components(separatedBy: .newlines).first ?? item.content
        let source = item.content.contains("\n")
            ? item.content.components(separatedBy: .newlines).dropFirst()
                .joined(separator: " ").trimmingCharacters(in: .whitespaces)
            : nil

        let active = item.includeInGeneration
        let bgColor: Color = active ? .dcBlue : Color(.systemGray5)
        let primaryColor: Color = active ? .white.opacity(0.8) : Color(.secondaryLabel)
        let secondaryColor: Color = active ? .white.opacity(0.7) : Color(.tertiaryLabel)
        let tertiaryColor: Color = active ? .white.opacity(0.5) : Color(.tertiaryLabel)
        let bodyColor: Color = active ? .white.opacity(0.9) : Color(.secondaryLabel)

        return VStack(alignment: .leading, spacing: 6) {
            // Domain label
            HStack(spacing: 4) {
                Image(systemName: "link")
                    .font(.caption2)
                Text(getDomain(url))
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(primaryColor)

            // URL text
            Text(url)
                .font(.caption)
                .foregroundStyle(secondaryColor)
                .lineLimit(1)
                .truncationMode(.middle)

            // Source metadata
            if let source, !source.isEmpty {
                Text(source)
                    .font(.caption2)
                    .foregroundStyle(tertiaryColor)
            }

            // Extracted text preview
            if let extracted = item.extractedText, !extracted.isEmpty {
                Divider()
                    .background(active ? .white.opacity(0.3) : .secondary.opacity(0.3))
                Text(extracted)
                    .font(.caption)
                    .foregroundStyle(bodyColor)
                    .lineLimit(3)
            }
        }
        .padding(12)
        .frame(maxWidth: 280, alignment: .leading)
        .background(bgColor, in: RoundedRectangle(cornerRadius: 16))
        .textSelection(.enabled)
        .onTapGesture {
            if let parsed = URL(string: url) {
                openURL(parsed)
            }
        }
    }

    // MARK: - Image Bubble

    private func imageBubble(_ item: InputItem) -> some View {
        AuthenticatedImageView(path: item.content) { uiImage in
            fullscreenImage = uiImage
        }
        .frame(maxWidth: 240)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Composer Bar

    private var composerBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 8) {
                // Camera
                Button {
                    viewModel.showCamera = true
                } label: {
                    Image(systemName: "camera")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.dcBlue)
                        .frame(height: 36)
                }

                // Photo picker
                PhotosPicker(
                    selection: $viewModel.selectedPhoto,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.dcBlue)
                        .frame(height: 36)
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
                    .focused($isComposerFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 20))
                    .submitLabel(.send)
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
                        .frame(height: 36)
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

    // MARK: - Export Handler

    func handleExport() async {
        do {
            let text = try await viewModel.exportDay()
            UIPasteboard.general.string = text
            exportCopied = true
            try? await Task.sleep(for: .seconds(2))
            exportCopied = false
        } catch {}
    }

    // MARK: - Helpers

    @Environment(\.openURL) private var openURL
}

// MARK: - Make editingItemId work with .sheet(item:)

extension String: @retroactive Identifiable {
    public var id: String { self }
}

// MARK: - Camera (UIImagePickerController wrapper)

struct CameraView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    var onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        init(_ parent: CameraView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Authenticated Image View

struct AuthenticatedImageView: View {
    let path: String
    var onTap: ((UIImage) -> Void)?

    @State private var uiImage: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .onTapGesture { onTap?(uiImage) }
            } else if failed {
                imagePlaceholder(systemName: "exclamationmark.triangle", text: "Failed to load")
            } else {
                ProgressView()
                    .frame(width: 200, height: 150)
            }
        }
        .task { await loadImage() }
    }

    private func loadImage() async {
        guard let url = APIService.shared.imageURL(path: path) else {
            failed = true
            return
        }
        var request = URLRequest(url: url)
        if let token = APIService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
               let image = UIImage(data: data) {
                uiImage = image
            } else {
                failed = true
            }
        } catch {
            failed = true
        }
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
}

// MARK: - Fullscreen Image View

struct FullscreenImageView: View {
    let image: UIImage
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(1.0 - min(abs(dragOffset.height) / CGFloat(300), 0.5))
                .ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(y: dragOffset.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if scale <= 1.0 {
                                dragOffset = value.translation
                            }
                        }
                        .onEnded { value in
                            if abs(value.translation.height) > 120 {
                                onDismiss()
                            } else {
                                withAnimation(.spring(duration: 0.25)) {
                                    dragOffset = .zero
                                }
                            }
                        }
                )
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in scale = value.magnification }
                        .onEnded { _ in withAnimation { scale = max(1.0, scale) } }
                )
                .onTapGesture(count: 2) {
                    withAnimation { scale = scale > 1 ? 1.0 : 2.0 }
                }

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding()
            }
        }
    }
}

// MARK: - UIImage Identifiable for .fullScreenCover(item:)

extension UIImage: @retroactive Identifiable {
    public var id: ObjectIdentifier { ObjectIdentifier(self) }
}

#Preview {
    FeedView()
}
