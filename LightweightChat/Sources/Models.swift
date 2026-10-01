import Foundation

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String // "user" or "assistant"
    let content: String
    var failure: String? = nil
}

struct LLMModel: Identifiable, Hashable {
    let id: String
    let label: String
}

let availableModels: [LLMModel] = [
    LLMModel(id: "google/gemini-3.8-flash", label: "Gemini 3.8 Flash"),
    LLMModel(id: "google/gemma-4-31b-it", label: "Gemma 4 31B"),
    LLMModel(id: "x-ai/grok-4.6", label: "Grok 4.6"),
    LLMModel(id: "minimax/minimax-m3", label: "MiniMax M3"),
    LLMModel(id: "xiaomi/mimo-v2.6-pro", label: "MiMo 2.6 Pro"),
    LLMModel(id: "xiaomi/mimo-v2.6-flash", label: "MiMo 2.6 Flash"),
    LLMModel(id: "z-ai/glm-5.3-flash:nitro", label: "GLM 5.3 Flash (Nitro)"),
    LLMModel(id: "anthropic/claude-sonnet-5.5:nitro", label: "Claude Sonnet 5.5 (Nitro)"),
    LLMModel(id: "anthropic/claude-opus-5.5", label: "Claude Opus 5.5"),
    LLMModel(id: "anthropic/claude-fable-5.1:nitro", label: "Claude Fable 5.1 (Nitro)"),
    LLMModel(id: "anthropic/claude-haiku-4.5", label: "Claude Haiku 4.5"),
    LLMModel(id: "openai/gpt-6-luna", label: "GPT-6 Luna"),
    LLMModel(id: "openai/gpt-6-sol", label: "GPT-6 Sol"),
    LLMModel(id: "openai/gpt-6.1-sol", label: "GPT-6.1 Sol"),
    LLMModel(id: "openai/gpt-6-astra", label: "GPT-6 Astra"),
    LLMModel(id: "openai/gpt-oss-120b:nitro", label: "GPT-OSS 120B (Nitro)"),
]

let replacedModelIDs: [String: String] = [
    "anthropic/claude-sonnet-5": "anthropic/claude-sonnet-5.5:nitro",
    "anthropic/claude-opus-5": "anthropic/claude-opus-5.5",
    "openai/gpt-5.6-luna": "openai/gpt-6-luna",
    "openai/gpt-5.6-terra": "openai/gpt-6-sol",
    "openai/gpt-5.6-sol": "openai/gpt-6.1-sol",
]

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
