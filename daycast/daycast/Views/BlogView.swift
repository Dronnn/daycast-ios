import SwiftUI

struct BlogView: View {
    @State private var vm = BlogViewModel()

    private let channels: [(id: String?, label: String)] = [
        (nil, "All"),
        ("blog", "Blog"),
        ("diary", "Diary"),
        ("tg_personal", "Telegram"),
        ("twitter", "Twitter / X"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    channelFilterPills
                        .padding(.top, 8)
                        .padding(.bottom, 16)

                    if vm.isLoading && vm.posts.isEmpty {
                        skeletonList
                    } else if vm.posts.isEmpty {
                        emptyState
                    } else {
                        postList
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await vm.fetchPosts()
            }
            .navigationTitle("Blog")
        }
    }

    // MARK: - Channel Filter Pills

    private var channelFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(channels, id: \.label) { channel in
                    Button {
                        vm.selectChannel(channel.id)
                    } label: {
                        Text(channel.label)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(vm.selectedChannel == channel.id ? .white : .primary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                            .background(
                                vm.selectedChannel == channel.id
                                    ? AnyShapeStyle(Color.dcBlue)
                                    : AnyShapeStyle(Color(.tertiarySystemFill))
                            )
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Post List

    private var postList: some View {
        LazyVStack(spacing: 16) {
            ForEach(vm.posts) { post in
                NavigationLink(value: post) {
                    postCard(post)
                }
                .buttonStyle(.plain)
            }

            // Infinite scroll sentinel
            if vm.hasMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .onAppear {
                        Task { await vm.loadMore() }
                    }
            }
        }
        .navigationDestination(for: PublishedPostResponse.self) { post in
            BlogPostDetailView(slug: post.slug)
        }
    }

    // MARK: - Post Card

    private func postCard(_ post: PublishedPostResponse) -> some View {
        let channel = ChannelMeta.find(post.channelId)

        return VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ChannelIconView(channel: channel, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(channel.name)
                        .font(.system(size: 15, weight: .bold))
                        .tracking(-0.3)
                    Text(formatPublishDate(post.publishedAt))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            // Text preview
            Text(post.text)
                .font(.system(size: 14))
                .lineSpacing(4)
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

            // Badges
            HStack(spacing: 8) {
                badgePill(post.style.capitalized)
                badgePill(post.language.uppercased())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
        .shadow(color: .black.opacity(0.06), radius: 5, y: 3)
        .shadow(color: .black.opacity(0.06), radius: 18, y: 12)
    }

    private func badgePill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(.tertiarySystemFill))
            .clipShape(Capsule())
    }

    // MARK: - Skeleton

    private var skeletonList: some View {
        VStack(spacing: 16) {
            ForEach(0..<4, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        ShimmerView()
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 6) {
                            ShimmerView()
                                .frame(width: 100, height: 14)
                                .clipShape(Capsule())
                            ShimmerView()
                                .frame(width: 70, height: 10)
                                .clipShape(Capsule())
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        ShimmerView().frame(height: 12).clipShape(Capsule())
                        ShimmerView().frame(height: 12).clipShape(Capsule())
                        ShimmerView().frame(width: 160, height: 12).clipShape(Capsule())
                    }
                    HStack(spacing: 8) {
                        ShimmerView().frame(width: 70, height: 24).clipShape(Capsule())
                        ShimmerView().frame(width: 40, height: 24).clipShape(Capsule())
                    }
                }
                .padding(20)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 24))
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 80)
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No published posts yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer().frame(height: 80)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    BlogView()
}
