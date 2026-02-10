import SwiftUI

struct BlogPostDetailView: View {
    let slug: String

    @State private var post: PublishedPostResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var copied = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let post {
                postContent(post)
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text(errorMessage)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let post {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    ShareLink(item: post.text) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Button {
                        UIPasteboard.general.string = post.text
                        copied = true
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            copied = false
                        }
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    }
                }
            }
        }
        .task {
            await loadPost()
        }
    }

    // MARK: - Content

    private func postContent(_ post: PublishedPostResponse) -> some View {
        let channel = ChannelMeta.find(post.channelId)

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Channel header
                HStack(spacing: 14) {
                    ChannelIconView(channel: channel, size: 56)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(channel.name)
                            .font(.system(size: 20, weight: .bold))
                            .tracking(-0.5)
                        Text(formatPublishDate(post.publishedAt))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }

                // Badges
                HStack(spacing: 8) {
                    badgePill(post.style.capitalized)
                    badgePill(post.language.uppercased())
                }

                // Full text
                Text(post.text)
                    .font(.system(size: 17))
                    .lineSpacing(8)
                    .frame(maxWidth: 600, alignment: .leading)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .scrollIndicators(.hidden)
    }

    private func badgePill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemFill))
            .clipShape(Capsule())
    }

    // MARK: - Load

    private func loadPost() async {
        isLoading = true
        do {
            post = try await APIService.shared.fetchPublicPost(slug: slug)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
