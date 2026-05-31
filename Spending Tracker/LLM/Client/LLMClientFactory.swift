import Foundation

enum LLMClientFactory {
    static func make(_ config: LLMConfig) -> LLMClient {
        switch config.provider {
        case .ollama:
            return OllamaClient(config: config)
        }
    }
}
