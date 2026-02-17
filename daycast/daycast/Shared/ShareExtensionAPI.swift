import Foundation

enum ShareInputType: String, Codable {
    case text
    case url
    case image
}

struct ShareInputCreateRequest: Codable {
    let type: ShareInputType
    let content: String
    let date: String
}

struct ShareInputItem: Codable, Identifiable {
    let id: String
    let type: ShareInputType
    let content: String
    let date: String
}

enum ShareAPIError: LocalizedError {
    case notAuthenticated
    case invalidURL
    case serverError(Int, String?)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: "Not logged in"
        case .invalidURL: "Invalid URL"
        case .serverError(let code, let msg): msg ?? "Server error (\(code))"
        case .networkError(let err): err.localizedDescription
        }
    }
}

struct ShareAPIClient {
    static let baseURL = "https://daycast.mrmaier.com/api/v1"

    static func createItem(type: ShareInputType, content: String) async throws -> ShareInputItem {
        guard let token = SharedTokenStorage.getToken() else {
            throw ShareAPIError.notAuthenticated
        }
        guard let url = URL(string: "\(baseURL)/inputs") else {
            throw ShareAPIError.invalidURL
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())

        let body = ShareInputCreateRequest(type: type, content: content, date: today)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ShareAPIError.serverError(0, "Invalid response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8)
            throw ShareAPIError.serverError(http.statusCode, msg)
        }

        return try JSONDecoder().decode(ShareInputItem.self, from: data)
    }

    static func uploadImage(imageData: Data, filename: String = "photo.jpg") async throws -> ShareInputItem {
        guard let token = SharedTokenStorage.getToken() else {
            throw ShareAPIError.notAuthenticated
        }
        guard let url = URL(string: "\(baseURL)/inputs/upload") else {
            throw ShareAPIError.invalidURL
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"date\"\r\n\r\n".data(using: .utf8)!)
        body.append(today.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ShareAPIError.serverError(0, "Invalid response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8)
            throw ShareAPIError.serverError(http.statusCode, msg)
        }

        return try JSONDecoder().decode(ShareInputItem.self, from: data)
    }
}
