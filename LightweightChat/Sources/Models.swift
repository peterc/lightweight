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

struct ModelCatalog: Decodable, Equatable {
    let models: [LLMModel]
    let replacedModelIDs: [String: String]

    static func decode(_ data: Data) throws -> ModelCatalog {
        let catalog = try JSONDecoder().decode(ModelCatalog.self, from: data)
        let ids = Set(catalog.models.map(\.id))
        guard !catalog.models.isEmpty,
              ids.count == catalog.models.count,
              catalog.models.allSatisfy({ !$0.id.isEmpty && !$0.label.isEmpty &&
                  $0.id.rangeOfCharacter(from: .whitespacesAndNewlines) == nil }),
              catalog.replacedModelIDs.allSatisfy({ !$0.key.isEmpty && ids.contains($0.value) }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return catalog
    }

    func selection(for savedID: String, customModels: [LLMModel]) -> LLMModel {
        let alternativeID = savedID.hasSuffix(":nitro") ? String(savedID.dropLast(6)) : "\(savedID):nitro"
        let previousBaseID = savedID.hasSuffix(":nitro") ? alternativeID : savedID
        return (models + customModels).first { $0.id == savedID }
            ?? models.first { $0.id == alternativeID }
            ?? models.first { $0.id == replacedModelIDs[previousBaseID] }
            ?? models[0]
    }

    static let bundled: ModelCatalog = {
        do {
            guard let url = Bundle.main.url(forResource: "models", withExtension: "json") else {
                fatalError("Missing bundled models.json")
            }
            return try decode(Data(contentsOf: url))
        } catch {
            fatalError("Could not load bundled models.json: \(error)")
        }
    }()
}

enum CustomModels {
    static func parse(_ text: String, excluding builtInModels: [LLMModel] = []) -> [LLMModel] {
        var seen = Set(builtInModels.map(\.id))
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
