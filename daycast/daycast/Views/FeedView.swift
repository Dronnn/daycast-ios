import SwiftUI
import PhotosUI
import UIKit

struct FeedView: View {
    @State private var viewModel = FeedViewModel()
    @State private var showClearConfirmation = false
    @State private var fullscreenImage: UIImage?
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
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await viewModel.fetchItems() }
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
        let url = item.content.components(separatedBy: .newlines).first ?? item.content
        let source = item.content.contains("\n")
            ? item.content.components(separatedBy: .newlines).dropFirst()
                .joined(separator: " ").trimmingCharacters(in: .whitespaces)
            : nil

        return VStack(alignment: .leading, spacing: 6) {
            // Domain label
            HStack(spacing: 4) {
                Image(systemName: "link")
                    .font(.caption2)
                Text(getDomain(url))
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.white.opacity(0.8))

            // URL text
            Text(url)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .truncationMode(.middle)

            // Source metadata
            if let source, !source.isEmpty {
                Text(source)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }

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
