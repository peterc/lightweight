import Foundation

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String // "user" or "assistant"
    let content: String
    var failure: String? = nil
}

struct LLMModel: Identifiable, Hashable, Decodable {
    let id: String
    let label: String
}

struct ModelCatalog: Decodable {
    let models: [LLMModel]
    let replacedModelIDs: [String: String]

    static let bundled: ModelCatalog = {
        do {
            guard let url = Bundle.main.url(forResource: "models", withExtension: "json") else {
                fatalError("Missing bundled models.json")
            }
            let catalog = try JSONDecoder().decode(ModelCatalog.self, from: Data(contentsOf: url))
            // The first model is the default selection, so the catalog cannot be empty.
            guard !catalog.models.isEmpty else {
                fatalError("Bundled models.json must contain at least one model")
            }
            return catalog
        } catch {
            fatalError("Could not load bundled models.json: \(error)")
        }
    }()
}

let availableModels = ModelCatalog.bundled.models
let replacedModelIDs = ModelCatalog.bundled.replacedModelIDs

enum CustomModels {
    static func parse(_ text: String) -> [LLMModel] {
        var seen = Set(availableModels.map(\.id))
        return text.components(separatedBy: .newlines).compactMap { line in
            let id = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty, seen.insert(id).inserted else { return nil }
            return LLMModel(id: id, label: id)
        }
    }
}

// OpenRouter API types
struct APIRequest: Encodable {
    let model: String
    let messages: [APIMessage]
    let stream: Bool
}

struct APIMessage: Codable {
    let role: String
    let content: String
}

struct APIResponse: Decodable {
    let choices: [Choice]?
    let error: APIError?

    struct Choice: Decodable {
        let message: APIMessage?
        let delta: Delta?
        let finish_reason: String?
    }

    struct Delta: Decodable {
        let content: String?
    }

    struct APIError: Decodable {
        let message: String
    }
}
