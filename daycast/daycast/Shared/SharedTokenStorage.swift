import Foundation

enum SharedTokenStorage {
    private static let suiteName = "group.ch.origin.daycast"
    private static let tokenKey = "daycast_token"
    private static let usernameKey = "daycast_username"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    static func getToken() -> String? {
        defaults?.string(forKey: tokenKey)
    }

    static func saveToken(_ token: String) {
        defaults?.set(token, forKey: tokenKey)
    }

    static func getUsername() -> String? {
        defaults?.string(forKey: usernameKey)
    }

    static func saveUsername(_ username: String) {
        defaults?.set(username, forKey: usernameKey)
    }

    static func clearAuth() {
        defaults?.removeObject(forKey: tokenKey)
        defaults?.removeObject(forKey: usernameKey)
    }

    static var isAuthenticated: Bool {
        getToken() != nil
    }

    // MARK: - Migration from UserDefaults.standard

    static func migrateFromStandardDefaultsIfNeeded() {
        let standard = UserDefaults.standard
        let migrationKey = "daycast_token_migrated_to_app_group"

        guard !standard.bool(forKey: migrationKey) else { return }

        if let token = standard.string(forKey: tokenKey), getToken() == nil {
            saveToken(token)
            standard.removeObject(forKey: tokenKey)
        }
        if let username = standard.string(forKey: usernameKey), getUsername() == nil {
            saveUsername(username)
            standard.removeObject(forKey: usernameKey)
        }

        standard.set(true, forKey: migrationKey)
    }
}
