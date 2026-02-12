import Foundation

enum APIServiceError: LocalizedError {
    case invalidURL
    case serverError(String)
    case decodingError(Error)
    case networkError(Error)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid URL"
        case .serverError(let msg): msg
        case .decodingError(let err): "Decoding error: \(err.localizedDescription)"
        case .networkError(let err): err.localizedDescription
        case .unauthorized: "Session expired"
        }
    }
}

struct AuthRequest: Codable, Sendable {
    let username: String
    let password: String
}

struct AuthResponse: Codable, Sendable {
    let token: String
    let username: String
}

extension Notification.Name {
    static let sessionExpired = Notification.Name("sessionExpired")
}

struct APIService: Sendable {
    static let shared = APIService()

    let baseURL = "http://192.168.31.131:8000/api/v1"

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        return e
    }()

    // MARK: - Token Management

    func getToken() -> String? {
        SharedTokenStorage.getToken()
    }

    func saveToken(_ token: String) {
        SharedTokenStorage.saveToken(token)
    }

    func saveUsername(_ username: String) {
        SharedTokenStorage.saveUsername(username)
    }

    func getUsername() -> String? {
        SharedTokenStorage.getUsername()
    }

    func clearAuth() {
        SharedTokenStorage.clearAuth()
    }

    var isAuthenticated: Bool {
        SharedTokenStorage.isAuthenticated
    }

    // MARK: - Auth Endpoints

    func auth(action: String, username: String, password: String) async throws -> AuthResponse {
        guard let url = URL(string: "\(baseURL)/auth/\(action)") else {
            throw APIServiceError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(AuthRequest(username: username, password: password))

        let (data, response) = try await URLSession.shared.data(for: req)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            if let apiErr = try? decoder.decode(APIError.self, from: data) {
                throw APIServiceError.serverError(apiErr.error)
            }
            throw APIServiceError.serverError("HTTP \(http.statusCode)")
        }

        return try decoder.decode(AuthResponse.self, from: data)
    }

    // MARK: - Generic request

    private func request<T: Decodable>(
        _ method: String,
        path: String,
        body: (any Encodable)? = nil
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIServiceError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = getToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            req.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: req)

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 401 {
                NotificationCenter.default.post(name: .sessionExpired, object: nil)
                throw APIServiceError.unauthorized
            }
            if !(200..<300).contains(http.statusCode) {
                if let apiErr = try? decoder.decode(APIError.self, from: data) {
                    throw APIServiceError.serverError(apiErr.error)
                }
                throw APIServiceError.serverError("HTTP \(http.statusCode)")
            }
        }

        if data.isEmpty, let empty = EmptyResponse() as? T {
            return empty
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIServiceError.decodingError(error)
        }
    }

    private func requestVoid(
        _ method: String,
        path: String,
        body: (any Encodable)? = nil
    ) async throws {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIServiceError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = getToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            req.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: req)

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 401 {
                NotificationCenter.default.post(name: .sessionExpired, object: nil)
                throw APIServiceError.unauthorized
            }
            if !(200..<300).contains(http.statusCode) {
                if let apiErr = try? decoder.decode(APIError.self, from: data) {
                    throw APIServiceError.serverError(apiErr.error)
                }
                throw APIServiceError.serverError("HTTP \(http.statusCode)")
            }
        }
    }

    // MARK: - Input Items

    func fetchItems(date: String) async throws -> [InputItem] {
        try await request("GET", path: "/inputs?date=\(date)")
    }

    func createItem(_ item: InputItemCreateRequest) async throws -> InputItem {
        try await request("POST", path: "/inputs", body: item)
    }

    func updateItem(id: String, content: String) async throws -> InputItem {
        try await request("PUT", path: "/inputs/\(id)", body: InputItemUpdateRequest(content: content))
    }

    func deleteItem(id: String) async throws {
        try await requestVoid("DELETE", path: "/inputs/\(id)")
    }

    func clearDay(date: String) async throws {
        try await requestVoid("DELETE", path: "/inputs?date=\(date)")
    }

    func updateItemFields(id: String, importance: Int? = nil, includeInGeneration: Bool? = nil) async throws -> InputItem {
        struct UpdateRequest: Encodable {
            var importance: Int?
            var includeInGeneration: Bool?

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                if let importance {
                    try container.encode(importance, forKey: .importance)
                }
                if let includeInGeneration {
                    try container.encode(includeInGeneration, forKey: .includeInGeneration)
                }
            }

            enum CodingKeys: String, CodingKey {
                case importance
                case includeInGeneration = "include_in_generation"
            }
        }
        let body = UpdateRequest(importance: importance, includeInGeneration: includeInGeneration)
        return try await request("PUT", path: "/inputs/\(id)", body: body)
    }

    // MARK: - Image Upload

    func uploadImage(imageData: Data, date: String, filename: String = "photo.jpg") async throws -> InputItem {
        guard let url = URL(string: "\(baseURL)/inputs/upload") else {
            throw APIServiceError.invalidURL
        }

        let boundary = UUID().uuidString
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = getToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        // File part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        // Date part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"date\"\r\n\r\n".data(using: .utf8)!)
        body.append(date.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        // Importance part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"importance\"\r\n\r\n".data(using: .utf8)!)
        body.append("5".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        // End
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 401 {
                NotificationCenter.default.post(name: .sessionExpired, object: nil)
                throw APIServiceError.unauthorized
            }
            if !(200..<300).contains(http.statusCode) {
                if let apiErr = try? decoder.decode(APIError.self, from: data) {
                    throw APIServiceError.serverError(apiErr.error)
                }
                throw APIServiceError.serverError("HTTP \(http.statusCode)")
            }
        }

        return try decoder.decode(InputItem.self, from: data)
    }

    func imageURL(path: String) -> URL? {
        URL(string: "\(baseURL)/uploads/\(path)")
    }

    // MARK: - Generation

    func generate(date: String) async throws -> Generation {
        try await request("POST", path: "/generate", body: GenerateRequest(date: date))
    }

    func regenerate(generationId: String, channels: [String]? = nil) async throws -> Generation {
        try await request("POST", path: "/generate/\(generationId)/regenerate", body: RegenerateRequest(channels: channels))
    }

    // MARK: - Days / History

    func fetchDays(search: String? = nil) async throws -> DayListResponse {
        var path = "/days"
        if let search, !search.isEmpty {
            path += "?search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search)"
        }
        return try await request("GET", path: path)
    }

    func fetchDay(date: String) async throws -> DayResponse {
        try await request("GET", path: "/days/\(date)")
    }

    func deleteDay(date: String) async throws {
        try await requestVoid("DELETE", path: "/days/\(date)")
    }

    // MARK: - Publishing

    func publishPost(resultId: String) async throws -> PublishedPostResponse {
        try await request("POST", path: "/publish", body: PublishRequest(generationResultId: resultId))
    }

    func unpublishPost(postId: String) async throws {
        try await requestVoid("DELETE", path: "/publish/\(postId)")
    }

    func getPublishStatus(resultIds: [String]) async throws -> PublishStatusResponse {
        let ids = resultIds.joined(separator: ",")
        return try await request("GET", path: "/publish/status?result_ids=\(ids)")
    }

    // MARK: - Public Feed (no auth)

    func fetchPublicPosts(cursor: String? = nil, limit: Int = 10, channel: String? = nil) async throws -> PublicPostListResponse {
        var path = "/public/posts?limit=\(limit)"
        if let cursor { path += "&cursor=\(cursor)" }
        if let channel { path += "&channel=\(channel)" }
        return try await request("GET", path: path)
    }

    func fetchPublicPost(slug: String) async throws -> PublishedPostResponse {
        try await request("GET", path: "/public/posts/\(slug)")
    }

    // MARK: - Channel Settings

    func fetchChannelSettings() async throws -> [ChannelSetting] {
        try await request("GET", path: "/settings/channels")
    }

    func saveChannelSettings(_ settings: [ChannelSetting]) async throws {
        try await requestVoid("POST", path: "/settings/channels", body: SaveChannelSettingsRequest(channels: settings))
    }

    // MARK: - Publish Input

    func publishInputItem(inputItemId: String) async throws -> PublishedPostResponse {
        let body = PublishInputRequest(inputItemId: inputItemId)
        return try await request("POST", path: "/publish/input", body: body)
    }

    func getInputPublishStatus(inputIds: [String]) async throws -> PublishStatusResponse {
        let ids = inputIds.joined(separator: ",")
        return try await request("GET", path: "/publish/input-status?input_ids=\(ids)")
    }

    // MARK: - Generation Settings

    func getGenerationSettings() async throws -> GenerationSettingsResponse {
        try await request("GET", path: "/settings/generation")
    }

    func saveGenerationSettings(_ settings: GenerationSettingsRequest) async throws -> GenerationSettingsResponse {
        try await request("POST", path: "/settings/generation", body: settings)
    }

    // MARK: - Export

    func exportDay(date: String) async throws -> ExportResponse {
        try await request("GET", path: "/inputs/export?date=\(date)&format=plain")
    }
}

private struct EmptyResponse: Decodable {}
