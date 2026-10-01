import Foundation

@main
struct ModelCatalogChecks {
    @MainActor
    static func main() async throws {
        let base = URL(string: CommandLine.arguments[1])!
        let temporary = URL(fileURLWithPath: CommandLine.arguments[2])
        let bundled = try ModelCatalog.decode(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[3])))
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let suite = "lightweight-catalog-check-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let cache = temporary.appendingPathComponent("cache/models.json")

        func store(_ path: String) -> ModelCatalogStore {
            ModelCatalogStore(bundled: bundled, remoteURL: base.appendingPathComponent(path),
                              cacheURL: cache, defaults: defaults, session: session)
        }

        let fresh = store("valid")
        precondition(fresh.catalog == bundled)
        // Multiple windows share one store; simultaneous checks must issue one request.
        async let first: Void = fresh.refreshIfNeeded(now: now)
        async let second: Void = fresh.refreshIfNeeded(now: now)
        _ = await (first, second)
        precondition(fresh.catalog.models[0].id == "test/new")
        let updated = fresh.catalog
        let persisted = try ModelCatalog.decode(Data(contentsOf: cache))
        precondition(persisted == updated)
        let cached = store("valid")
        precondition(cached.catalog == updated)
        await cached.refreshIfNeeded(now: now.addingTimeInterval(60))
        precondition(cached.catalog == updated)
        await cached.refreshIfNeeded(now: now.addingTimeInterval(86_400))

        for (index, path) in ["invalid", "empty", "duplicate", "bad-replacement", "http-error", "oversized", "disconnect"].enumerated() {
            let fallback = store(path)
            let date = now.addingTimeInterval(Double(index + 2) * 86_400)
            await fallback.refreshIfNeeded(now: date)
            await fallback.refreshIfNeeded(now: date.addingTimeInterval(60))
            precondition(fallback.catalog == updated, "Failed fallback for \(path)")
            let retained = try ModelCatalog.decode(Data(contentsOf: cache))
            precondition(retained == updated)
        }
        try Data("broken".utf8).write(to: cache)
        precondition(store("valid").catalog == bundled)

        let custom = CustomModels.parse("test/new\n test/custom \ntest/custom", excluding: updated.models)
        precondition(custom.map(\.id) == ["test/custom"])
        precondition(CustomModels.parse("test/new").count == 1) // Stored entries are independent.
        precondition(updated.selection(for: "test/old:nitro", customModels: custom).id == "test/new")
        precondition(updated.selection(for: "test/custom", customModels: custom).id == "test/custom")
        precondition(updated.selection(for: "unknown", customModels: []).id == "test/new")
        let nitro = ModelCatalog(models: [LLMModel(id: "test/fast:nitro", label: "Fast")], replacedModelIDs: [:])
        precondition(nitro.selection(for: "test/fast", customModels: []).id == "test/fast:nitro")
        print("Catalog caching, throttling, failure handling and selection checks passed")
    }
}
