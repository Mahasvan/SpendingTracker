import Foundation
import Observation

@MainActor
@Observable
final class ModelCapabilityStore {
    private let settings: AppSettings

    var availableModels: [String] = []
    var capabilities: ModelCapabilities?
    var checkedModel: String?
    var isLoadingModels = false
    var isLoadingCapabilities = false
    var errorMessage: String?

    init(settings: AppSettings) {
        self.settings = settings
    }

    var hasTools: Bool { capabilities?.hasTools ?? false }
    var hasVision: Bool { capabilities?.hasVision ?? false }
    var hasThinking: Bool { capabilities?.hasThinking ?? false }

    /// True only when we positively know the current model lacks tool support.
    var toolsUnsupported: Bool {
        capabilities != nil && capabilities?.hasTools == false
    }

    func refreshModels() async {
        guard let client = introspection() else { return }
        isLoadingModels = true
        errorMessage = nil
        defer { isLoadingModels = false }
        do {
            availableModels = try await client.listModels()
        } catch {
            errorMessage = (error as? LLMError)?.errorDescription ?? error.localizedDescription
        }
    }

    func loadCapabilities(force: Bool = false) async {
        let model = settings.ollamaModel
        guard !model.isEmpty else {
            capabilities = nil
            checkedModel = nil
            return
        }
        if !force, checkedModel == model, capabilities != nil { return }
        guard let client = introspection() else { return }
        isLoadingCapabilities = true
        errorMessage = nil
        defer { isLoadingCapabilities = false }
        do {
            let caps = try await client.capabilities(model: model)
            capabilities = caps
            checkedModel = model
        } catch {
            capabilities = nil
            checkedModel = nil
            errorMessage = (error as? LLMError)?.errorDescription ?? error.localizedDescription
        }
    }

    func refreshAll() async {
        await refreshModels()
        await loadCapabilities(force: true)
    }

    private func introspection() -> OllamaIntrospection? {
        guard let url = URL(string: settings.ollamaBaseURL) else { return nil }
        return OllamaIntrospection(baseURL: url)
    }
}
