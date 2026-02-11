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
    let importance: Int?
    let includeInGeneration: Bool

    enum CodingKeys: String, CodingKey {
        case id, type, content, date, cleared, edits, importance
        case extractedText = "extracted_text"
        case extractError = "extract_error"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case includeInGeneration = "include_in_generation"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(InputItemType.self, forKey: .type)
        content = try container.decode(String.self, forKey: .content)
        extractedText = try container.decodeIfPresent(String.self, forKey: .extractedText)
        extractError = try container.decodeIfPresent(String.self, forKey: .extractError)
        date = try container.decode(String.self, forKey: .date)
        cleared = try container.decode(Bool.self, forKey: .cleared)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        edits = try container.decodeIfPresent([InputItemEdit].self, forKey: .edits)
        importance = try container.decodeIfPresent(Int.self, forKey: .importance)
        includeInGeneration = try container.decodeIfPresent(Bool.self, forKey: .includeInGeneration) ?? true
    }

    init(id: String, type: InputItemType, content: String, extractedText: String?, extractError: String?, date: String, cleared: Bool, createdAt: String, updatedAt: String, edits: [InputItemEdit]? = nil, importance: Int? = nil, includeInGeneration: Bool = true) {
        self.id = id
        self.type = type
        self.content = content
        self.extractedText = extractedText
        self.extractError = extractError
        self.date = date
        self.cleared = cleared
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.edits = edits
        self.importance = importance
        self.includeInGeneration = includeInGeneration
    }
}

struct InputItemCreateRequest: Codable, Sendable {
    let type: InputItemType
    let content: String
    let date: String
    var importance: Int?
    var includeInGeneration: Bool?

    enum CodingKeys: String, CodingKey {
        case type, content, date, importance
        case includeInGeneration = "include_in_generation"
    }
}

struct InputItemUpdateRequest: Codable, Sendable {
    var content: String?
    var importance: Int?
    var includeInGeneration: Bool?

    enum CodingKeys: String, CodingKey {
        case content, importance
        case includeInGeneration = "include_in_generation"
    }
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

struct PublishedPostResponse: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let slug: String
    let channelId: String?
    let style: String?
    let language: String?
    let text: String
    let date: String
    let publishedAt: String
    let inputItemsPreview: [String]
    let source: String?

    enum CodingKeys: String, CodingKey {
        case id, slug, style, language, text, date, source
        case channelId = "channel_id"
        case publishedAt = "published_at"
        case inputItemsPreview = "input_items_preview"
    }
}

struct PublishStatusResponse: Codable, Sendable {
    let statuses: [String: String?]
}

struct PublishInputRequest: Codable, Sendable {
    let inputItemId: String

    enum CodingKeys: String, CodingKey {
        case inputItemId = "input_item_id"
    }
}

struct ExportResponse: Codable, Sendable {
    let text: String
    let date: String
    let count: Int
}

// MARK: - Generation Settings

struct GenerationSettingsRequest: Codable, Sendable {
    var customInstruction: String?
    var separateBusinessPersonal: Bool

    enum CodingKeys: String, CodingKey {
        case customInstruction = "custom_instruction"
        case separateBusinessPersonal = "separate_business_personal"
    }
}

struct GenerationSettingsResponse: Codable, Sendable {
    var customInstruction: String?
    var separateBusinessPersonal: Bool

    enum CodingKeys: String, CodingKey {
        case customInstruction = "custom_instruction"
        case separateBusinessPersonal = "separate_business_personal"
    }
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

// MARK: - Public Feed

struct PublicPostListResponse: Codable, Sendable {
    let items: [PublishedPostResponse]
    let cursor: String?
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case items, cursor
        case hasMore = "has_more"
    }
}

// MARK: - Static Catalog

enum StyleOption: String, CaseIterable, Sendable {
    case concise, detailed, structured, plan, advisory, casual, funny, serious
    case listNumbered = "list_numbered"
    case listBulleted = "list_bulleted"

    var displayName: String {
        switch self {
        case .listNumbered: "List (Numbered)"
        case .listBulleted: "List (Bulleted)"
        default: rawValue.capitalized
        }
    }
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
