import Foundation

// MARK: - Input Items

enum InputItemType: String, Codable, CaseIterable, Sendable {
    case text
    case url
    case image
}

struct InputItemEdit: Codable, Identifiable, Sendable {
    let id: String
    let oldContent: String
    let editedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case oldContent = "old_content"
        case editedAt = "edited_at"
    }
}

struct InputItem: Codable, Identifiable, Sendable {
    let id: String
    let type: InputItemType
    let content: String
    let extractedText: String?
    let extractError: String?
    let date: String
    let cleared: Bool
    let createdAt: String
    let updatedAt: String
    var edits: [InputItemEdit]?

    enum CodingKeys: String, CodingKey {
        case id, type, content, date, cleared, edits
        case extractedText = "extracted_text"
        case extractError = "extract_error"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct InputItemCreateRequest: Codable, Sendable {
    let type: InputItemType
    let content: String
    let date: String
}

struct InputItemUpdateRequest: Codable, Sendable {
    let content: String
}

// MARK: - Generation

struct GenerateRequest: Codable, Sendable {
    let date: String
    var channels: [String]?
    var styleOverride: String?
    var languageOverride: String?

    enum CodingKeys: String, CodingKey {
        case date, channels
        case styleOverride = "style_override"
        case languageOverride = "language_override"
    }
}

struct RegenerateRequest: Codable, Sendable {
    var channels: [String]?
}

struct GenerationResult: Codable, Identifiable, Sendable {
    let id: String
    let channelId: String
    let style: String
    let language: String
    let text: String
    let model: String

    enum CodingKeys: String, CodingKey {
        case id, style, language, text, model
        case channelId = "channel_id"
    }
}

struct Generation: Codable, Identifiable, Sendable {
    let id: String
    let date: String
    let results: [GenerationResult]
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, date, results
        case createdAt = "created_at"
    }
}

// MARK: - Publishing

struct PublishRequest: Codable, Sendable {
    let generationResultId: String

    enum CodingKeys: String, CodingKey {
        case generationResultId = "generation_result_id"
    }
}

struct PublishedPostResponse: Codable, Identifiable, Sendable {
    let id: String
    let slug: String
    let channelId: String
    let style: String
    let language: String
    let text: String
    let date: String
    let publishedAt: String
    let inputItemsPreview: [String]

    enum CodingKeys: String, CodingKey {
        case id, slug, style, language, text, date
        case channelId = "channel_id"
        case publishedAt = "published_at"
        case inputItemsPreview = "input_items_preview"
    }
}

struct PublishStatusResponse: Codable, Sendable {
    let statuses: [String: String?]
}

// MARK: - Days / History

struct DayResponse: Codable, Sendable {
    let date: String
    let inputItems: [InputItem]
    let generations: [Generation]

    enum CodingKeys: String, CodingKey {
        case date, generations
        case inputItems = "input_items"
    }
}

struct DaySummary: Codable, Identifiable, Hashable, Sendable {
    let date: String
    let inputCount: Int
    let generationCount: Int

    var id: String { date }

    enum CodingKeys: String, CodingKey {
        case date
        case inputCount = "input_count"
        case generationCount = "generation_count"
    }
}

struct DayListResponse: Codable, Sendable {
    let items: [DaySummary]
    let cursor: String?
}

// MARK: - Channel Settings

struct ChannelSetting: Codable, Sendable {
    let channelId: String
    var isActive: Bool
    var defaultStyle: String
    var defaultLanguage: String
    var defaultLength: String

    enum CodingKeys: String, CodingKey {
        case channelId = "channel_id"
        case isActive = "is_active"
        case defaultStyle = "default_style"
        case defaultLanguage = "default_language"
        case defaultLength = "default_length"
    }
}

struct SaveChannelSettingsRequest: Codable, Sendable {
    let channels: [ChannelSetting]
}

// MARK: - Error

struct APIError: Codable, Sendable {
    let error: String
    let code: String
    let detail: String?
}

// MARK: - Channel Metadata (static)

struct ChannelMeta: Identifiable, Sendable {
    let id: String
    let name: String
    let description: String
    let letter: String
    let gradientColors: [String] // hex colors for gradient

    static let all: [ChannelMeta] = [
        ChannelMeta(id: "blog", name: "Blog", description: "Long-form, structured post", letter: "B", gradientColors: ["#0071e3", "#00c6fb"]),
        ChannelMeta(id: "diary", name: "Diary", description: "Personal reflection, private tone", letter: "D", gradientColors: ["#bf5af2", "#ff6bcb"]),
        ChannelMeta(id: "tg_personal", name: "Telegram Personal", description: "Informal, for close friends", letter: "T", gradientColors: ["#2AABEE", "#229ED9"]),
        ChannelMeta(id: "tg_public", name: "Telegram Public", description: "Informative, for your audience", letter: "T", gradientColors: ["#2AABEE", "#229ED9"]),
        ChannelMeta(id: "twitter", name: "Twitter / X", description: "Short and punchy, 280 chars", letter: "X", gradientColors: ["#1d1d1f", "#555555"]),
    ]

    static func find(_ id: String) -> ChannelMeta {
        all.first(where: { $0.id == id }) ?? ChannelMeta(id: id, name: id, description: "", letter: String(id.prefix(1)).uppercased(), gradientColors: ["#888888", "#aaaaaa"])
    }
}

// MARK: - Static Catalog

enum StyleOption: String, CaseIterable, Sendable {
    case concise, detailed, structured, plan, advisory, casual, funny, serious
}

enum LengthOption: String, CaseIterable, Sendable {
    case brief, short, medium, detailed, full

    var label: String {
        rawValue.capitalized
    }
}

enum LanguageOption: String, CaseIterable, Sendable {
    case ru, en, de, hy

    var label: String {
        switch self {
        case .ru: "Russian"
        case .en: "English"
        case .de: "German"
        case .hy: "Armenian"
        }
    }
}
