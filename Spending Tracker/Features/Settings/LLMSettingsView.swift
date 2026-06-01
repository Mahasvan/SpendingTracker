import SwiftUI

struct LLMSettingsView: View {
    @Bindable var settings: AppSettings
    let store: ModelCapabilityStore

    var body: some View {
        Form {
            Section("Provider") {
                Picker("LLM Provider", selection: $settings.provider) {
                    ForEach(LLMProvider.allCases) { p in
                        Text(p.displayName).tag(p)
                    }
                }
            }
            Section("Ollama") {
                TextField("Base URL", text: $settings.ollamaBaseURL)
                modelRow
                if store.availableModels.isEmpty {
                    TextField("Model", text: $settings.ollamaModel)
                        .help("No models were fetched. Enter a model name manually or tap Refresh.")
                }
                HStack {
                    Text("Temperature: \(String(format: "%.2f", settings.temperature))")
                    Slider(value: $settings.temperature, in: 0...1)
                }
            }
            Section("Model Capabilities") {
                capabilitiesRow
            }
            Section("Reasoning") {
                reasoningRow
            }
            Section("Tool Permissions") {
                Picker("Read tools", selection: $settings.readPolicy) {
                    ForEach(ToolConfirmPolicy.allCases) { p in
                        Text(p.displayName).tag(p)
                    }
                }
                Picker("Write tools", selection: $settings.writePolicy) {
                    ForEach(ToolConfirmPolicy.allCases) { p in
                        Text(p.displayName).tag(p)
                    }
                }
                Picker("Delete tools", selection: $settings.deletePolicy) {
                    ForEach(ToolConfirmPolicy.allCases) { p in
                        Text(p.displayName).tag(p)
                    }
                }
            }
            Section("Chat") {
                Toggle("Persist chat history", isOn: $settings.persistChatHistory)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("LLM Settings")
        .task {
            await store.refreshAll()
        }
        .onChange(of: settings.ollamaModel) { _, _ in
            Task { await store.loadCapabilities(force: true) }
        }
        .onChange(of: settings.ollamaBaseURL) { _, _ in
            Task { await store.refreshAll() }
        }
    }

    @ViewBuilder
    private var modelRow: some View {
        HStack {
            if store.availableModels.isEmpty {
                Text("Model")
                Spacer()
                Text(settings.ollamaModel.isEmpty ? "Not set" : settings.ollamaModel)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Model", selection: $settings.ollamaModel) {
                    ForEach(modelOptions, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
            }
            Button {
                Task { await store.refreshAll() }
            } label: {
                if store.isLoadingModels {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderless)
            .help("Reload installed models and capabilities from Ollama")
        }
    }

    private var modelOptions: [String] {
        var set = store.availableModels
        if !settings.ollamaModel.isEmpty, !set.contains(settings.ollamaModel) {
            set.insert(settings.ollamaModel, at: 0)
        }
        return set
    }

    @ViewBuilder
    private var capabilitiesRow: some View {
        if store.isLoadingCapabilities {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Checking capabilities…").foregroundStyle(.secondary)
            }
        } else if let caps = store.capabilities {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    capabilityBadge("Tools", systemImage: "wrench.and.screwdriver", on: caps.hasTools)
                    capabilityBadge("Vision", systemImage: "photo", on: caps.hasVision)
                    capabilityBadge("Thinking", systemImage: "brain", on: caps.hasThinking)
                }
                if !caps.hasTools {
                    Label("This model does not support tool calling. The chatbot needs tools to read and modify your data, so sending is disabled until you pick a tool-capable model.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        } else if let err = store.errorMessage {
            Label(err, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("Capabilities unknown. Tap Refresh.")
                .foregroundStyle(.secondary)
        }
    }

    private func capabilityBadge(_ title: String, systemImage: String, on: Bool) -> some View {
        Label(title, systemImage: on ? "checkmark.seal.fill" : "xmark.seal")
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill((on ? Color.green : Color.secondary).opacity(0.15))
            )
            .foregroundStyle(on ? Color.green : Color.secondary)
    }

    @ViewBuilder
    private var reasoningRow: some View {
        if store.hasThinking {
            Picker("Reasoning effort", selection: $settings.reasoningLevel) {
                ForEach(ReasoningLevel.allCases) { level in
                    Text(level.displayName).tag(level)
                }
            }
            Text("Controls how much the model thinks before answering. gpt-oss models can't be turned off; \"Off\" maps to Low.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("The selected model does not support reasoning.")
                .foregroundStyle(.secondary)
        }
    }
}
