import Foundation
import Combine

@MainActor
final class ModelCatalogStore: ObservableObject {
    static let shared = ModelCatalogStore()
    static let remoteURL = URL(string: "https://raw.githubusercontent.com/peterc/lightweight/main/LightweightChat/Resources/models.json")!

    @Published private(set) var catalog: ModelCatalog

    private let remoteURL: URL
    private let cacheURL: URL
    private let defaults: UserDefaults
    private let session: URLSession
    private var isRefreshing = false
    private static let lastAttemptKey = "model_catalog_last_attempt"
    private static let maximumSize = 64 * 1024

    init(bundled: ModelCatalog = .bundled,
         remoteURL: URL? = nil,
         cacheURL: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("org.peterc.lightweight/models.json"),
         defaults: UserDefaults = .standard,
         session: URLSession = .shared) {
        self.remoteURL = remoteURL ?? Self.remoteURL
        self.cacheURL = cacheURL
        self.defaults = defaults
        self.session = session
        if let data = try? Data(contentsOf: cacheURL), data.count <= Self.maximumSize,
           let cached = try? ModelCatalog.decode(data) {
            catalog = cached
        } else {
            catalog = bundled
        }
    }

    func refreshIfNeeded(now: Date = Date()) async {
        guard !isRefreshing else { return }
        if let lastAttempt = defaults.object(forKey: Self.lastAttemptKey) as? Date,
           now.timeIntervalSince(lastAttempt) >= 0,
           now.timeIntervalSince(lastAttempt) < 24 * 60 * 60 { return }

        isRefreshing = true
        // Throttle failed attempts too, including across launches and windows.
        defaults.set(now, forKey: Self.lastAttemptKey)
        defer { isRefreshing = false }

        do {
            var request = URLRequest(url: remoteURL, timeoutInterval: 15)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (bytes, response) = try await session.bytes(for: request)
            guard let response = response as? HTTPURLResponse,
                  response.statusCode == 200,
                  response.expectedContentLength <= Self.maximumSize else { return }
            var data = Data()
            for try await byte in bytes {
                guard data.count < Self.maximumSize else { return }
                data.append(byte)
            }
            let updated = try ModelCatalog.decode(data)
            try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: cacheURL, options: .atomic)
            catalog = updated
        } catch {
            // Refresh failures leave the cached or bundled catalog available.
        }
    }
}
