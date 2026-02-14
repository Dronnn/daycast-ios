import Foundation
import Network

@MainActor
@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    /// True when device has network AND server is reachable.
    /// All existing code that checks `isConnected` automatically gets
    /// the correct offline behavior for "internet present but server down".
    var isConnected: Bool {
        hasNetwork && isServerReachable
    }

    /// Device has a network interface (WiFi / cellular).
    private(set) var hasNetwork = true

    /// Server responded to a recent API call or health-check.
    private(set) var isServerReachable = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var healthCheckTask: Task<Void, Never>?

    private init() {
        startMonitoring()
    }

    // MARK: - NWPathMonitor

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.hasNetwork = connected
                // When device regains network, immediately check server
                if connected, self?.isServerReachable == false {
                    self?.startHealthCheck()
                }
            }
        }
        monitor.start(queue: queue)
    }

    // MARK: - Server Reachability Reporting

    /// Called by DataRepository after a successful API response.
    func reportSuccess() {
        guard !isServerReachable else { return }
        isServerReachable = true
        stopHealthCheck()
    }

    /// Called by DataRepository when an API call fails.
    /// Only marks server unreachable for network-level errors
    /// (connection refused, timeout, DNS failure, etc.).
    /// HTTP errors (4xx, 5xx) mean the server IS reachable.
    func reportFailure(_ error: Error) {
        guard isNetworkLevelError(error) else {
            // Server responded with an error — it's reachable
            if !isServerReachable {
                isServerReachable = true
                stopHealthCheck()
            }
            return
        }
        guard isServerReachable else { return }
        isServerReachable = false
        startHealthCheck()
    }

    // MARK: - Health Check (periodic server ping)

    private func startHealthCheck() {
        stopHealthCheck()
        healthCheckTask = Task { [weak self] in
            var interval: UInt64 = 5
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }
                guard let self, self.hasNetwork, !self.isServerReachable else { continue }
                await self.pingServer()
                // Back off: 5 → 10 → 15, cap at 15s
                interval = min(interval + 5, 15)
            }
        }
    }

    private func stopHealthCheck() {
        healthCheckTask?.cancel()
        healthCheckTask = nil
    }

    private func pingServer() async {
        // /health is at root level, not under /api/v1
        let base = APIService.shared.baseURL
        let rootURL = base.replacingOccurrences(of: "/api/v1", with: "")
        guard let url = URL(string: "\(rootURL)/health") else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                // Server responded — mark reachable
                isServerReachable = true
                stopHealthCheck()
            }
        } catch {
            // Still unreachable — health check will retry
        }
    }

    // MARK: - Error Classification

    func isNetworkLevelError(_ error: Error) -> Bool {
        // Direct URLError from URLSession
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotConnectToHost,
                 .timedOut,
                 .networkConnectionLost,
                 .notConnectedToInternet,
                 .cannotFindHost,
                 .dnsLookupFailed,
                 .secureConnectionFailed,
                 .cannotLoadFromNetwork,
                 .dataNotAllowed:
                return true
            default:
                return false
            }
        }
        // APIServiceError.networkError wraps an underlying error
        if case APIServiceError.networkError(let inner) = error {
            return isNetworkLevelError(inner)
        }
        return false
    }
}
