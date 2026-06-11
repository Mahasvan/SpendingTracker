import Foundation

enum LLMClientFactory {
    static func make(_ config: LLMConfig) -> LLMClient {
        switch config.provider {
        case .ollama:
            return OllamaClient(config: config)
        case .appleFoundation:
            if #available(macOS 26.0, iOS 26.0, *) {
                return AppleFoundationClient(config: config)
            } else {
                // Fallback: should not reach here if UI properly guards availability
                return OllamaClient(config: config)
            }
        }
    }
}
