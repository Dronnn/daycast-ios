import Foundation

enum APIServiceError: LocalizedError {
    case invalidURL
    case serverError(String)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid URL"
        case .serverError(let msg): msg
        case .decodingError(let err): "Decoding error: \(err.localizedDescription)"
        case .networkError(let err): err.localizedDescription
        }
    }
}

struct APIService: Sendable {
    static let shared = APIService()

    let baseURL = "http://192.168.31.131:8000/api/v1"
    let clientId = "00000000-0000-4000-a000-000000000001"

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        return e
    }()

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
        req.setValue(clientId, forHTTPHeaderField: "X-Client-ID")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            req.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: req)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            if let apiErr = try? decoder.decode(APIError.self, from: data) {
                throw APIServiceError.serverError(apiErr.error)
            }
            throw APIServiceError.serverError("HTTP \(http.statusCode)")
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
        req.setValue(clientId, forHTTPHeaderField: "X-Client-ID")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            req.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: req)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            if let apiErr = try? decoder.decode(APIError.self, from: data) {
                throw APIServiceError.serverError(apiErr.error)
            }
            throw APIServiceError.serverError("HTTP \(http.statusCode)")
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

    // MARK: - Image Upload

    func uploadImage(imageData: Data, date: String, filename: String = "photo.jpg") async throws -> InputItem {
        guard let url = URL(string: "\(baseURL)/inputs/upload") else {
            throw APIServiceError.invalidURL
        }

        let boundary = UUID().uuidString
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(clientId, forHTTPHeaderField: "X-Client-ID")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

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
        // End
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            if let apiErr = try? decoder.decode(APIError.self, from: data) {
                throw APIServiceError.serverError(apiErr.error)
            }
            throw APIServiceError.serverError("HTTP \(http.statusCode)")
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

    // MARK: - Channel Settings

    func fetchChannelSettings() async throws -> [ChannelSetting] {
        try await request("GET", path: "/settings/channels")
    }

    func saveChannelSettings(_ settings: [ChannelSetting]) async throws {
        try await requestVoid("POST", path: "/settings/channels", body: SaveChannelSettingsRequest(channels: settings))
    }
}

private struct EmptyResponse: Decodable {}
