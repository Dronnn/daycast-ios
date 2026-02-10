import SwiftUI

struct ChannelsView: View {

    @Binding var isAuthenticated: Bool
    @State private var viewModel = ChannelsViewModel()
    @State private var showLogoutConfirmation = false

    var body: some View {
        NavigationStack {
        Form {
            // Channel sections
            ForEach(ChannelMeta.all) { channel in
                channelSection(channel)
            }

            // Error
            if let error = viewModel.errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.showSaved {
                savedToast
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.showSaved)
        .task {
            await viewModel.loadSettings()
        }
        .navigationTitle("Channels")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showLogoutConfirmation = true
                    } label: {
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .fontWeight(.medium)
                }
            }
        }
        .confirmationDialog(
            "Are you sure you want to log out?",
            isPresented: $showLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Log Out", role: .destructive) {
                APIService.shared.clearAuth()
                isAuthenticated = false
            }
        }
        } // NavigationStack
    }

    // MARK: - Channel Section

    @ViewBuilder
    private func channelSection(_ channel: ChannelMeta) -> some View {
        let setting = viewModel.setting(for: channel.id)
        let isActive = setting.isActive

        Section {
            // Row: icon + info + toggle
            HStack(spacing: 12) {
                ChannelIconView(channel: channel, size: 48)
                    .opacity(isActive ? 1 : 0.4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(channel.name)
                        .font(.body.weight(.medium))
                    Text(channel.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .opacity(isActive ? 1 : 0.5)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { setting.isActive },
                    set: { newValue in
                        viewModel.updateChannel(channel.id) { $0.isActive = newValue }
                    }
                ))
                .labelsHidden()
            }

            if isActive {
                // Style picker
                pickerRow(
                    label: "Style",
                    icon: "paintbrush",
                    selection: Binding(
                        get: { setting.defaultStyle },
                        set: { newValue in
                            viewModel.updateChannel(channel.id) { $0.defaultStyle = newValue }
                        }
                    ),
                    options: StyleOption.allCases.map { ($0.rawValue, $0.rawValue.capitalized) }
                )

                // Language picker
                pickerRow(
                    label: "Language",
                    icon: "globe",
                    selection: Binding(
                        get: { setting.defaultLanguage },
                        set: { newValue in
                            viewModel.updateChannel(channel.id) { $0.defaultLanguage = newValue }
                        }
                    ),
                    options: LanguageOption.allCases.map { ($0.rawValue, $0.label) }
                )

                // Length picker
                pickerRow(
                    label: "Length",
                    icon: "ruler",
                    selection: Binding(
                        get: { setting.defaultLength },
                        set: { newValue in
                            viewModel.updateChannel(channel.id) { $0.defaultLength = newValue }
                        }
                    ),
                    options: LengthOption.allCases.map { ($0.rawValue, $0.label) }
                )
            }
        }
    }

    // MARK: - Picker Row

    private func pickerRow(
        label: String,
        icon: String,
        selection: Binding<String>,
        options: [(value: String, display: String)]
    ) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.subheadline)

            Spacer()

            Picker(label, selection: selection) {
                ForEach(options, id: \.value) { option in
                    Text(option.display).tag(option.value)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }

    // MARK: - Saved Toast

    private var savedToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
            Text("Saved!")
                .fontWeight(.medium)
        }
        .font(.subheadline)
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.green.gradient, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .padding(.bottom, 24)
    }
}

#Preview {
    ChannelsView(isAuthenticated: .constant(true))
}
