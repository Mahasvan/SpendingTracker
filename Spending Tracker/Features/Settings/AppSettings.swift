import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.ollamaBaseURL = defaults.string(forKey: K.ollamaBaseURL) ?? "http://localhost:11434"
        self.ollamaModel = defaults.string(forKey: K.ollamaModel) ?? "llama3.1"
        self.temperature = defaults.object(forKey: K.temperature) as? Double ?? 0.2
        if let raw = defaults.string(forKey: K.provider),
           let p = LLMProvider(rawValue: raw) {
            self.provider = p
        } else {
            self.provider = .ollama
        }
        if let raw = defaults.string(forKey: K.readPolicy),
           let p = ToolConfirmPolicy(rawValue: raw) {
            self.readPolicy = p
        } else {
            self.readPolicy = .auto
        }
        if let raw = defaults.string(forKey: K.writePolicy),
           let p = ToolConfirmPolicy(rawValue: raw) {
            self.writePolicy = p
        } else {
            self.writePolicy = .confirm
        }
        if let raw = defaults.string(forKey: K.deletePolicy),
           let p = ToolConfirmPolicy(rawValue: raw) {
            self.deletePolicy = p
        } else {
            self.deletePolicy = .confirm
        }
        self.persistChatHistory = defaults.object(forKey: K.persistChat) as? Bool ?? true
    }

    var provider: LLMProvider {
        didSet { defaults.set(provider.rawValue, forKey: K.provider) }
    }
    var ollamaBaseURL: String {
        didSet { defaults.set(ollamaBaseURL, forKey: K.ollamaBaseURL) }
    }
    var ollamaModel: String {
        didSet { defaults.set(ollamaModel, forKey: K.ollamaModel) }
    }
    var temperature: Double {
        didSet { defaults.set(temperature, forKey: K.temperature) }
    }
    var readPolicy: ToolConfirmPolicy {
        didSet { defaults.set(readPolicy.rawValue, forKey: K.readPolicy) }
    }
    var writePolicy: ToolConfirmPolicy {
        didSet { defaults.set(writePolicy.rawValue, forKey: K.writePolicy) }
    }
    var deletePolicy: ToolConfirmPolicy {
        didSet { defaults.set(deletePolicy.rawValue, forKey: K.deletePolicy) }
    }
    var persistChatHistory: Bool {
        didSet { defaults.set(persistChatHistory, forKey: K.persistChat) }
    }

    private enum K {
        static let provider = "llm.provider"
        static let ollamaBaseURL = "llm.ollama.baseURL"
        static let ollamaModel = "llm.ollama.model"
        static let temperature = "llm.temperature"
        static let readPolicy = "tools.policy.read"
        static let writePolicy = "tools.policy.write"
        static let deletePolicy = "tools.policy.delete"
        static let persistChat = "chat.persist"
    }
}
