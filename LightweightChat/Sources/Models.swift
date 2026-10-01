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
    LLMModel(id: "google/gemini-3.8-flash:nitro", label: "Gemini 3.8 Flash"),
    LLMModel(id: "google/gemma-4-31b-it:nitro", label: "Gemma 4 31B"),
    LLMModel(id: "x-ai/grok-4.6:nitro", label: "Grok 4.6 Nitro"),
    LLMModel(id: "minimax/minimax-m3:nitro", label: "MiniMax M3"),
    LLMModel(id: "z-ai/glm-5.3-flash:nitro", label: "GLM 5.3 Flash"),
    LLMModel(id: "anthropic/claude-sonnet-5:nitro", label: "Claude Sonnet 5"),
    LLMModel(id: "anthropic/claude-opus-5:nitro", label: "Claude Opus 5"),
    LLMModel(id: "anthropic/claude-fable-5.1:nitro", label: "Claude Fable 5.1"),
    LLMModel(id: "anthropic/claude-haiku-4.5:nitro", label: "Claude Haiku 4.5"),
    LLMModel(id: "openai/gpt-5.6-luna:nitro", label: "GPT-5.6 Luna"),
    LLMModel(id: "openai/gpt-5.6-terra:nitro", label: "GPT-5.6 Terra"),
    LLMModel(id: "openai/gpt-5.6-sol:nitro", label: "GPT-5.6 Sol"),
    LLMModel(id: "openai/gpt-6-astra:nitro", label: "GPT-6 Astra"),
    LLMModel(id: "openai/gpt-oss-120b:nitro", label: "GPT-OSS 120B Nitro"),
]

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
