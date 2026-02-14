import Foundation
import SwiftData

// MARK: - Cached Input Item Edit

@Model
final class CachedInputItemEdit {
    var editId: String
    var oldContent: String
    var editedAt: String

    var parent: CachedInputItem?

    init(editId: String, oldContent: String, editedAt: String) {
        self.editId = editId
        self.oldContent = oldContent
        self.editedAt = editedAt
    }

    convenience init(from edit: InputItemEdit) {
        self.init(editId: edit.id, oldContent: edit.oldContent, editedAt: edit.editedAt)
    }

    func toApiModel() -> InputItemEdit {
        InputItemEdit(id: editId, oldContent: oldContent, editedAt: editedAt)
    }
}

// MARK: - Cached Input Item

@Model
final class CachedInputItem {
    #Index<CachedInputItem>([\.itemId], [\.date])

    var itemId: String
    var type: String
    var content: String
    var extractedText: String?
    var extractError: String?
    var date: String
    var cleared: Bool
    var createdAt: String
    var updatedAt: String
    var isLocal: Bool
    var localTempId: String?
    var importance: Int?
    var includeInGeneration: Bool = true

    @Relationship(deleteRule: .cascade) var edits: [CachedInputItemEdit]

    init(itemId: String, type: String, content: String, extractedText: String?, extractError: String?, date: String, cleared: Bool, createdAt: String, updatedAt: String, isLocal: Bool = false, localTempId: String? = nil, importance: Int? = nil, includeInGeneration: Bool = true) {
        self.itemId = itemId
        self.type = type
        self.content = content
        self.extractedText = extractedText
        self.extractError = extractError
        self.date = date
        self.cleared = cleared
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isLocal = isLocal
        self.localTempId = localTempId
        self.importance = importance
        self.includeInGeneration = includeInGeneration
        self.edits = []
    }

    convenience init(from item: InputItem) {
        self.init(
            itemId: item.id,
            type: item.type.rawValue,
            content: item.content,
            extractedText: item.extractedText,
            extractError: item.extractError,
            date: item.date,
            cleared: item.cleared,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt,
            importance: item.importance,
            includeInGeneration: item.includeInGeneration
        )
        self.edits = (item.edits ?? []).map { CachedInputItemEdit(from: $0) }
    }

    func toApiModel() -> InputItem {
        InputItem(
            id: itemId,
            type: InputItemType(rawValue: type) ?? .text,
            content: content,
            extractedText: extractedText,
            extractError: extractError,
            date: date,
            cleared: cleared,
            createdAt: createdAt,
            updatedAt: updatedAt,
            edits: edits.map { $0.toApiModel() },
            importance: importance,
            includeInGeneration: includeInGeneration
        )
    }
}

// MARK: - Cached Generation Result

@Model
final class CachedGenerationResult {
    var resultId: String
    var channelId: String
    var style: String
    var language: String
    var text: String
    var model: String

    var parent: CachedGeneration?

    init(resultId: String, channelId: String, style: String, language: String, text: String, model: String) {
        self.resultId = resultId
        self.channelId = channelId
        self.style = style
        self.language = language
        self.text = text
        self.model = model
    }

    convenience init(from result: GenerationResult) {
        self.init(resultId: result.id, channelId: result.channelId, style: result.style, language: result.language, text: result.text, model: result.model)
    }

    func toApiModel() -> GenerationResult {
        GenerationResult(id: resultId, channelId: channelId, style: style, language: language, text: text, model: model)
    }
}

// MARK: - Cached Generation

@Model
final class CachedGeneration {
    #Index<CachedGeneration>([\.date])

    var generationId: String
    var date: String
    var createdAt: String

    @Relationship(deleteRule: .cascade) var results: [CachedGenerationResult]

    init(generationId: String, date: String, createdAt: String) {
        self.generationId = generationId
        self.date = date
        self.createdAt = createdAt
        self.results = []
    }

    convenience init(from gen: Generation) {
        self.init(generationId: gen.id, date: gen.date, createdAt: gen.createdAt)
        self.results = gen.results.map { CachedGenerationResult(from: $0) }
    }

    func toApiModel() -> Generation {
        Generation(
            id: generationId,
            date: date,
            results: results.map { $0.toApiModel() },
            createdAt: createdAt
        )
    }
}

// MARK: - Cached Day Summary

@Model
final class CachedDaySummary {
    #Index<CachedDaySummary>([\.date])

    var date: String
    var inputCount: Int
    var generationCount: Int
    var lastFetchedAt: Date

    init(date: String, inputCount: Int, generationCount: Int, lastFetchedAt: Date = .now) {
        self.date = date
        self.inputCount = inputCount
        self.generationCount = generationCount
        self.lastFetchedAt = lastFetchedAt
    }

    convenience init(from summary: DaySummary) {
        self.init(date: summary.date, inputCount: summary.inputCount, generationCount: summary.generationCount)
    }

    func toApiModel() -> DaySummary {
        DaySummary(date: date, inputCount: inputCount, generationCount: generationCount)
    }
}

// MARK: - Cached Channel Setting

@Model
final class CachedChannelSetting {
    var channelId: String
    var isActive: Bool
    var defaultStyle: String
    var defaultLanguage: String
    var defaultLength: String

    init(channelId: String, isActive: Bool, defaultStyle: String, defaultLanguage: String, defaultLength: String) {
        self.channelId = channelId
        self.isActive = isActive
        self.defaultStyle = defaultStyle
        self.defaultLanguage = defaultLanguage
        self.defaultLength = defaultLength
    }

    convenience init(from setting: ChannelSetting) {
        self.init(channelId: setting.channelId, isActive: setting.isActive, defaultStyle: setting.defaultStyle, defaultLanguage: setting.defaultLanguage, defaultLength: setting.defaultLength)
    }

    func toApiModel() -> ChannelSetting {
        ChannelSetting(channelId: channelId, isActive: isActive, defaultStyle: defaultStyle, defaultLanguage: defaultLanguage, defaultLength: defaultLength)
    }
}

// MARK: - Cached Blog Post

@Model
final class CachedBlogPost {
    #Index<CachedBlogPost>([\.slug], [\.channelId])

    var postId: String
    var slug: String
    var channelId: String?
    var style: String?
    var language: String?
    var text: String
    var date: String
    var publishedAt: String
    var inputItemsPreview: [String]
    var source: String?
    var cachedAt: Date

    init(postId: String, slug: String, channelId: String?, style: String?, language: String?, text: String, date: String, publishedAt: String, inputItemsPreview: [String], source: String?, cachedAt: Date = .now) {
        self.postId = postId
        self.slug = slug
        self.channelId = channelId
        self.style = style
        self.language = language
        self.text = text
        self.date = date
        self.publishedAt = publishedAt
        self.inputItemsPreview = inputItemsPreview
        self.source = source
        self.cachedAt = cachedAt
    }

    convenience init(from post: PublishedPostResponse) {
        self.init(
            postId: post.id,
            slug: post.slug,
            channelId: post.channelId,
            style: post.style,
            language: post.language,
            text: post.text,
            date: post.date,
            publishedAt: post.publishedAt,
            inputItemsPreview: post.inputItemsPreview,
            source: post.source
        )
    }

    func toApiModel() -> PublishedPostResponse {
        PublishedPostResponse(
            id: postId,
            slug: slug,
            channelId: channelId,
            style: style,
            language: language,
            text: text,
            date: date,
            publishedAt: publishedAt,
            inputItemsPreview: inputItemsPreview,
            source: source
        )
    }
}

// MARK: - Pending Sync Operation

@Model
final class PendingSyncOperation {
    #Index<PendingSyncOperation>([\.createdAt])

    var operationType: String // create, update, delete, clearDay, uploadImage, saveChannelSettings
    var entityType: String   // inputItem, generation, channelSettings
    var entityId: String
    var payload: Data?
    var imageFilePath: String?
    var date: String
    var retryCount: Int
    var lastError: String?
    var createdAt: Date

    init(operationType: String, entityType: String, entityId: String, payload: Data? = nil, imageFilePath: String? = nil, date: String = "", retryCount: Int = 0, lastError: String? = nil) {
        self.operationType = operationType
        self.entityType = entityType
        self.entityId = entityId
        self.payload = payload
        self.imageFilePath = imageFilePath
        self.date = date
        self.retryCount = retryCount
        self.lastError = lastError
        self.createdAt = .now
    }
}

