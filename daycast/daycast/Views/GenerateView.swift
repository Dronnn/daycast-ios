import SwiftUI
import UIKit

struct GenerateView: View {
    @State private var vm = GenerateViewModel()
    @State private var appearAnimated = false

    private let columns = [
        GridItem(.adaptive(minimum: 300, maximum: 500), spacing: 20)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if vm.isLoading && !vm.hasGenerations {
                    loadingPlaceholder
                } else if vm.hasGenerations {
                    resultsSection
                } else {
                    heroSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await vm.fetchDay()
        }
        .overlay(alignment: .bottom) {
            if let error = vm.error {
                errorToast(error)
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 60)

            // Item count badge
            if vm.activeItemCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("\(vm.activeItemCount) item\(vm.activeItemCount == 1 ? "" : "s") ready")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color.dcBlue)
                .padding(.horizontal, 18)
                .padding(.vertical, 7)
                .background(Color.dcBlueBg)
                .clipShape(Capsule())
                .transition(.scale.combined(with: .opacity))
            }

            // Hero title
            VStack(spacing: 8) {
                Text("Turn your day into")
                    .font(.system(size: 40, weight: .black))
                    .tracking(-2)
                Text("content.")
                    .font(.system(size: 40, weight: .black))
                    .tracking(-2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#0071e3"), Color(hex: "#5856d6"), Color(hex: "#bf5af2")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .multilineTextAlignment(.center)

            // Description
            Text("Generate tailored content for all your channels from today's inputs.")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)

            // Generate button
            Button {
                Task { await vm.generate() }
            } label: {
                ZStack {
                    if vm.isGenerating {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)
                    } else {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 88, height: 88)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#0071e3"), Color(hex: "#5856d6"), Color(hex: "#bf5af2")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: Color(hex: "#0071e3").opacity(0.3), radius: 15, y: 6)
                .shadow(color: Color(hex: "#5856d6").opacity(0.15), radius: 25, y: 12)
            }
            .disabled(vm.isGenerating || vm.activeItemCount == 0)
            .scaleEffect(vm.isGenerating ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: vm.isGenerating)
            .padding(.top, 8)

            Spacer().frame(height: 40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 24)

            // Generation header
            resultsHeader

            // Source items toggle
            if !vm.items.isEmpty {
                sourceSection
            }

            // Results grid
            if let generation = vm.currentGeneration {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(Array(generation.results.enumerated()), id: \.element.id) { index, result in
                        resultCard(result)
                            .opacity(appearAnimated ? 1 : 0)
                            .offset(y: appearAnimated ? 0 : 24)
                            .animation(
                                .easeOut(duration: 0.5).delay(Double(index) * 0.08),
                                value: appearAnimated
                            )
                    }
                }
                .onAppear {
                    appearAnimated = false
                    withAnimation {
                        appearAnimated = true
                    }
                }
                .onChange(of: vm.currentGenIndex) {
                    appearAnimated = false
                    withAnimation {
                        appearAnimated = true
                    }
                }
            }

            // Skeleton during regeneration
            if vm.isGenerating {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(0..<4, id: \.self) { _ in
                        skeletonCard
                    }
                }
            }

            // Generate more button
            if vm.hasGenerations && !vm.isGenerating {
                Button {
                    Task { await vm.generate() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Generate More")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Color.dcBlue)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.dcBlueBg)
                    .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Results Header

    private var resultsHeader: some View {
        VStack(spacing: 16) {
            // Generation navigation
            if vm.generations.count > 1 {
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            vm.goToPreviousGeneration()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(vm.canGoBack ? Color.primary : Color(.tertiaryLabel))
                    }
                    .disabled(!vm.canGoBack)

                    Text("Generation #\(vm.currentGenIndex + 1)")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(0.72)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)

                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            vm.goToNextGeneration()
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(vm.canGoForward ? Color.primary : Color(.tertiaryLabel))
                    }
                    .disabled(!vm.canGoForward)
                }
            }

            // Title + Regenerate All
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    if vm.generations.count <= 1 {
                        Text("GENERATION")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(0.72)
                            .foregroundStyle(.secondary)
                    }
                    Text("Your Content")
                        .font(.system(size: 32, weight: .heavy))
                        .tracking(-1.3)
                }

                Spacer()

                Button {
                    Task { await vm.regenerateAll() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Regenerate All")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
                }
                .disabled(vm.isGenerating)
            }

            // Timestamp
            if let generation = vm.currentGeneration {
                HStack {
                    Text(formatTime(generation.createdAt))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Source Section

    private var sourceSection: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    vm.showSource.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: vm.showSource ? "eye.slash" : "eye")
                        .font(.system(size: 12, weight: .medium))
                    Text(vm.showSource ? "Hide Sources" : "Show Sources")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.secondary)
            }

            if vm.showSource {
                VStack(spacing: 8) {
                    ForEach(vm.items.filter { !$0.cleared }) { item in
                        sourceItemRow(item)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
    }

    private func sourceItemRow(_ item: InputItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconForType(item.type))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(item.content)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Result Card

    private func resultCard(_ result: GenerationResult) -> some View {
        let channel = ChannelMeta.find(result.channelId)

        return VStack(alignment: .leading, spacing: 0) {
            // Card header
            HStack(spacing: 12) {
                ChannelIconView(channel: channel, size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(channel.name)
                        .font(.system(size: 16, weight: .bold))
                        .tracking(-0.4)

                    Text("\(result.style.capitalized) \u{00B7} \(result.language.uppercased())")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 16)

            // Card body
            Text(result.text)
                .font(.system(size: 14))
                .lineSpacing(4)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

            // Card footer
            HStack(spacing: 10) {
                // Copy button
                Button {
                    vm.copyText(result.text, resultId: result.id)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: vm.copiedResultId == result.id ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11, weight: .semibold))
                        Text(vm.copiedResultId == result.id ? "Copied" : "Copy")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Color.dcBlue)
                    .clipShape(Capsule())
                }

                // Regenerate button
                Button {
                    Task { await vm.regenerateChannel(result.channelId) }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Regenerate")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Capsule())
                }

                // Publish / Unpublish
                if let postId = vm.publishStatus[result.id] as? String {
                    // Published state
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Published")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Color.dcGreen)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.dcGreen.opacity(0.1))
                    .clipShape(Capsule())

                    Button {
                        Task { await vm.unpublishPost(resultId: result.id) }
                    } label: {
                        Text("Unpublish")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(Capsule())
                    }
                } else {
                    Button {
                        Task { await vm.publishPost(resultId: result.id) }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Publish")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Color.dcGreen)
                        .clipShape(Capsule())
                    }
                    .disabled(vm.isPublishing)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
        .shadow(color: .black.opacity(0.06), radius: 5, y: 3)
        .shadow(color: .black.opacity(0.06), radius: 18, y: 12)
    }

    // MARK: - Skeleton Card

    private var skeletonCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ShimmerView()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 6) {
                    ShimmerView()
                        .frame(width: 100, height: 14)
                        .clipShape(Capsule())
                    ShimmerView()
                        .frame(width: 60, height: 10)
                        .clipShape(Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ShimmerView()
                    .frame(height: 12)
                    .clipShape(Capsule())
                ShimmerView()
                    .frame(height: 12)
                    .clipShape(Capsule())
                ShimmerView()
                    .frame(width: 180, height: 12)
                    .clipShape(Capsule())
            }

            HStack(spacing: 10) {
                ShimmerView()
                    .frame(width: 80, height: 32)
                    .clipShape(Capsule())
                ShimmerView()
                    .frame(width: 110, height: 32)
                    .clipShape(Capsule())
            }
        }
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - Loading Placeholder

    private var loadingPlaceholder: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 60)
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading...")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.tertiary)
            Spacer().frame(height: 60)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Error Toast

    private func errorToast(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color(.systemBackground))
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(Color(.label))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.08), radius: 20, y: 8)
            .padding(.bottom, 36)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onTapGesture {
                withAnimation { vm.error = nil }
            }
    }

    // MARK: - Helpers

    private func iconForType(_ type: InputItemType) -> String {
        switch type {
        case .text: "text.quote"
        case .url: "link"
        case .image: "photo"
        }
    }
}

// MARK: - Shimmer Effect

private struct ShimmerView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        Color(.tertiarySystemFill)
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        Color.white.opacity(0.3),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
            )
            .clipped()
            .onAppear {
                withAnimation(
                    .linear(duration: 1.4)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 350
                }
            }
    }
}

#Preview {
    GenerateView()
}
