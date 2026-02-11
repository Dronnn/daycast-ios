import Foundation

@Observable
class ChannelsViewModel {

    // MARK: - State

    var settings: [String: ChannelSetting] = [:]
    var showSaved = false
    var isLoading = false
    var errorMessage: String?

    // Generation settings
    var customInstruction: String = ""
    var separateBusinessPersonal: Bool = false

    // MARK: - Private

    private let repo = DataRepository.shared

    // MARK: - Load

    func loadSettings() async {
        isLoading = true
        errorMessage = nil
        let fetched = await repo.fetchChannelSettings()
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
        await loadGenerationSettings()
        isLoading = false
    }

    // MARK: - Generation Settings

    func loadGenerationSettings() async {
        do {
            let settings = try await DataRepository.shared.getGenerationSettings()
            customInstruction = settings.customInstruction ?? ""
            separateBusinessPersonal = settings.separateBusinessPersonal
        } catch {}
    }

    func saveGenerationSettings() async {
        do {
            let request = GenerationSettingsRequest(
                customInstruction: customInstruction.isEmpty ? nil : customInstruction,
                separateBusinessPersonal: separateBusinessPersonal
            )
            _ = try await DataRepository.shared.saveGenerationSettings(request)
            showSaved = true
            try? await Task.sleep(for: .seconds(1.5))
            showSaved = false
        } catch {}
    }

    // MARK: - Save

    private func autoSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            errorMessage = nil
            let allSettings = ChannelMeta.all.compactMap { settings[$0.id] }
            await repo.saveChannelSettings(allSettings)
            showSaved = true
            try? await Task.sleep(for: .seconds(1.5))
            showSaved = false
        }
    }

    private var saveTask: Task<Void, Never>?

    // MARK: - Update

    func updateChannel(_ channelId: String, _ transform: (inout ChannelSetting) -> Void) {
        guard var setting = settings[channelId] else { return }
        transform(&setting)
        settings[channelId] = setting
        autoSave()
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
