import Foundation
import CryptoKit
import UIKit

actor ImageCacheService {
    static let shared = ImageCacheService()

    private let cacheDir: URL
    private var inMemoryCache: [String: UIImage] = [:]
    private let maxMemoryCacheCount = 50

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDir = docs.appendingPathComponent("cached_images", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    func getCachedImage(for path: String) -> UIImage? {
        if let img = inMemoryCache[path] { return img }
        let fileURL = fileURL(for: path)
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else { return nil }
        inMemoryCache[path] = image
        trimMemoryCache()
        return image
    }

    func cacheImage(data: Data, for path: String) {
        let fileURL = fileURL(for: path)
        try? data.write(to: fileURL)
        if let image = UIImage(data: data) {
            inMemoryCache[path] = image
            trimMemoryCache()
        }
    }

    func evictOldImages(maxDays: Int = 20) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.creationDateKey]) else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -maxDays, to: .now) ?? .now
        for file in files {
            if let attrs = try? file.resourceValues(forKeys: [.creationDateKey]),
               let created = attrs.creationDate, created < cutoff {
                try? FileManager.default.removeItem(at: file)
            }
        }
        inMemoryCache.removeAll()
    }

    private func fileURL(for path: String) -> URL {
        let hash = SHA256.hash(data: Data(path.utf8)).map { String(format: "%02x", $0) }.joined()
        return cacheDir.appendingPathComponent("\(hash).jpg")
    }

    private func trimMemoryCache() {
        if inMemoryCache.count > maxMemoryCacheCount {
            let keysToRemove = Array(inMemoryCache.keys.prefix(inMemoryCache.count / 2))
            for key in keysToRemove { inMemoryCache.removeValue(forKey: key) }
        }
    }
}
