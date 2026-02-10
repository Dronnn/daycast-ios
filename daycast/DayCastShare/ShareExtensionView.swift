import SwiftUI
import UniformTypeIdentifiers

struct ShareExtensionView: View {
    weak var extensionContext: NSExtensionContext?

    @State private var state: ViewState = .loading
    @State private var extractedContent: ExtractedContent?

    enum ViewState {
        case loading
        case preview
        case sending
        case success
        case error(String)
        case notAuthenticated
    }

    struct ExtractedContent {
        let type: ShareInputType
        let text: String
        let imageData: Data?

        var icon: String {
            switch type {
            case .url: "link"
            case .text: "doc.text"
            case .image: "photo"
            }
        }

        var displayText: String {
            if text.count > 200 {
                return String(text.prefix(200)) + "…"
            }
            return text
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { close() }
                Spacer()
                Text("DayCast")
                    .font(.headline)
                Spacer()
                Color.clear.frame(width: 60) // balance
            }
            .padding()
            .background(Color(.systemBackground))

            Divider()

            // Content
            Group {
                switch state {
                case .loading:
                    loadingView
                case .preview:
                    previewView
                case .sending:
                    sendingView
                case .success:
                    successView
                case .error(let message):
                    errorView(message: message)
                case .notAuthenticated:
                    notAuthenticatedView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .task { await extractContent() }
    }

    // MARK: - State Views

    private var loadingView: some View {
        ProgressView("Loading…")
    }

    private var previewView: some View {
        VStack(spacing: 20) {
            if let content = extractedContent {
                VStack(spacing: 12) {
                    Image(systemName: content.icon)
                        .font(.system(size: 36))
                        .foregroundStyle(.blue)

                    Text(content.displayText)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .lineLimit(6)
                        .padding(.horizontal)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)

                Button(action: { Task { await send() } }) {
                    Text("Add to DayCast")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
        }
    }

    private var sendingView: some View {
        ProgressView("Sending…")
    }

    private var successView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Added to DayCast")
                .font(.headline)
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 16) {
                Button("Cancel") { close() }
                    .foregroundStyle(.secondary)
                Button("Retry") { Task { await send() } }
                    .fontWeight(.semibold)
            }
        }
    }

    private var notAuthenticatedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Please log in to DayCast first")
                .font(.headline)
            Button("OK") { close() }
                .padding(.top, 8)
        }
    }

    // MARK: - Logic

    private func extractContent() async {
        guard SharedTokenStorage.isAuthenticated else {
            state = .notAuthenticated
            return
        }

        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            state = .error("No content to share")
            return
        }

        for item in items {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                // 1. URL
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
                        extractedContent = ExtractedContent(type: .url, text: url.absoluteString, imageData: nil)
                        state = .preview
                        return
                    }
                }
                // 2. Plain text
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
                        let type: ShareInputType = text.hasPrefix("http://") || text.hasPrefix("https://") ? .url : .text
                        extractedContent = ExtractedContent(type: type, text: text, imageData: nil)
                        state = .preview
                        return
                    }
                }
                // 3. Image
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    if let imageData = try? await loadImageData(from: provider) {
                        extractedContent = ExtractedContent(type: .image, text: "Photo", imageData: imageData)
                        state = .preview
                        return
                    }
                }
            }
        }

        state = .error("Unsupported content type")
    }

    private func loadImageData(from provider: NSItemProvider) async throws -> Data? {
        let item = try await provider.loadItem(forTypeIdentifier: UTType.image.identifier)

        var data: Data?

        if let url = item as? URL {
            data = try Data(contentsOf: url)
        } else if let image = item as? UIImage {
            data = image.jpegData(compressionQuality: 0.8)
        } else if let d = item as? Data {
            data = d
        }

        guard var imageData = data else { return nil }

        // Compress if over 5MB
        if imageData.count > 5_000_000, let image = UIImage(data: imageData) {
            var quality: CGFloat = 0.6
            while quality > 0.1 {
                if let compressed = image.jpegData(compressionQuality: quality), compressed.count <= 5_000_000 {
                    imageData = compressed
                    break
                }
                quality -= 0.1
            }
        }

        return imageData
    }

    private func send() async {
        guard let content = extractedContent else { return }
        state = .sending

        do {
            if content.type == .image, let imageData = content.imageData {
                _ = try await ShareAPIClient.uploadImage(imageData: imageData)
            } else {
                _ = try await ShareAPIClient.createItem(type: content.type, content: content.text)
            }
            state = .success
            try? await Task.sleep(for: .seconds(1.5))
            close()
        } catch let error as ShareAPIError {
            if case .notAuthenticated = error {
                state = .notAuthenticated
            } else {
                state = .error(error.localizedDescription)
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func close() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
