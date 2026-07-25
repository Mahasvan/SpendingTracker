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
        self.maxHistoryMessages = defaults.object(forKey: K.maxHistoryMessages) as? Int ?? 40
        self.requireBiometricUnlock = defaults.object(forKey: K.requireBiometricUnlock) as? Bool ?? true
        self.thinkingEnabled = defaults.object(forKey: K.thinkingEnabled) as? Bool ?? true
        self.useLLMVision = defaults.object(forKey: K.useLLMVision) as? Bool ?? true
        self.ollamaTimeout = defaults.object(forKey: K.ollamaTimeout) as? Double ?? 120
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
    /// Maximum number of trailing messages (besides the system prompt) sent to the model.
    var maxHistoryMessages: Int {
        didSet { defaults.set(maxHistoryMessages, forKey: K.maxHistoryMessages) }
    }
    /// When enabled, the app requires Touch ID (or the system password) on launch.
    var requireBiometricUnlock: Bool {
        didSet { defaults.set(requireBiometricUnlock, forKey: K.requireBiometricUnlock) }
    }
    /// Whether thinking-capable Ollama models should produce a reasoning trace.
    var thinkingEnabled: Bool {
        didSet { defaults.set(thinkingEnabled, forKey: K.thinkingEnabled) }
    }
    /// When true, images are sent directly to the model using its native vision capability.
    /// When false (or when the model has no vision), images are OCR'd on-device instead.
    var useLLMVision: Bool {
        didSet { defaults.set(useLLMVision, forKey: K.useLLMVision) }
    }
    /// HTTP request timeout (in seconds) for Ollama calls. Local models can take a
    /// while to load into memory before the first token, so this should be generous.
    var ollamaTimeout: Double {
        didSet { defaults.set(ollamaTimeout, forKey: K.ollamaTimeout) }
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
        static let maxHistoryMessages = "chat.maxHistoryMessages"
        static let requireBiometricUnlock = "security.requireBiometricUnlock"
        static let thinkingEnabled = "llm.thinking.enabled"
        static let useLLMVision = "llm.vision.enabled"
        static let ollamaTimeout = "llm.ollama.timeout"
    }
}
