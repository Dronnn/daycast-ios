import Foundation

@Observable
class ChannelsViewModel {

    // MARK: - State

    var settings: [String: ChannelSetting] = [:]
    var isSaving = false
    var showSaved = false
    var isLoading = false
    var errorMessage: String?

    // MARK: - Private

    private let api = APIService.shared

    // MARK: - Load

    func loadSettings() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await api.fetchChannelSettings()
            if fetched.isEmpty {
                buildDefaults()
            } else {
                settings = [:]
                for setting in fetched {
                    settings[setting.channelId] = setting
                }
                // Fill in any missing channels with defaults
                for channel in ChannelMeta.all where settings[channel.id] == nil {
                    settings[channel.id] = defaultSetting(for: channel.id)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            buildDefaults()
        }
        isLoading = false
    }

    // MARK: - Save

    func saveSettings() async {
        isSaving = true
        errorMessage = nil
        do {
            let allSettings = ChannelMeta.all.compactMap { settings[$0.id] }
            try await api.saveChannelSettings(allSettings)
            showSaved = true
            try? await Task.sleep(for: .seconds(2))
            showSaved = false
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    // MARK: - Update

    func updateChannel(_ channelId: String, _ transform: (inout ChannelSetting) -> Void) {
        guard var setting = settings[channelId] else { return }
        transform(&setting)
        settings[channelId] = setting
    }

    // MARK: - Helpers

    func setting(for channelId: String) -> ChannelSetting {
        settings[channelId] ?? defaultSetting(for: channelId)
    }

    private func buildDefaults() {
        settings = [:]
        for channel in ChannelMeta.all {
            settings[channel.id] = defaultSetting(for: channel.id)
        }
    }

    private func defaultSetting(for channelId: String) -> ChannelSetting {
        ChannelSetting(
            channelId: channelId,
            isActive: true,
            defaultStyle: StyleOption.concise.rawValue,
            defaultLanguage: LanguageOption.en.rawValue,
            defaultLength: LengthOption.medium.rawValue
        )
    }
}
