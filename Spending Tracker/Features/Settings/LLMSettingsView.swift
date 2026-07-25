import SwiftUI

struct LLMSettingsView: View {
    @Bindable var settings: AppSettings
    let store: ModelCapabilityStore

    var body: some View {
        Form {
            // MARK: - Provider picker
            Section("Provider") {
                Picker("LLM Provider", selection: $settings.provider) {
                    ForEach(LLMProvider.allCases) { p in
                        Label(p.displayName, systemImage: p.icon).tag(p)
                    }
                }
            }

            // MARK: - Apple Intelligence settings
            if settings.provider == .appleFoundation {
                appleIntelligenceSection
            }

            // MARK: - Ollama settings
            if settings.provider == .ollama {
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
                    HStack {
                        Text("Request timeout")
                        Spacer()
                        TextField("", value: $settings.ollamaTimeout, format: .number)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                        Text("s")
                        Stepper("", value: $settings.ollamaTimeout, in: 10...600, step: 5)
                            .labelsHidden()
                    }
                    Text("How long to wait for Ollama before aborting. Local models can take a while to load before the first token, so pick a generous value.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: - Model capabilities
            Section("Model Capabilities") {
                capabilitiesRow
                imageInputRow
            }

            // MARK: - Reasoning (Ollama-only, when model supports it)
            if settings.provider == .ollama {
                Section("Reasoning") {
                    reasoningRow
                }
            }

            // MARK: - Tool permissions
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

            // MARK: - Chat
            Section("Chat") {
                Toggle("Persist chat history", isOn: $settings.persistChatHistory)
                Stepper(value: $settings.maxHistoryMessages, in: 4...200, step: 2) {
                    Text("Message history limit: \(settings.maxHistoryMessages)")
                }
                Text("How many recent messages are sent to the model. Lower values keep the context small for smaller local models.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            if settings.provider == .ollama {
                Task { await store.refreshAll() }
            }
        }
        .onChange(of: settings.provider) { _, _ in
            Task { await store.refreshAll() }
        }
    }

    // MARK: - Apple Intelligence Section

    @ViewBuilder
    private var appleIntelligenceSection: some View {
        Section("Apple Intelligence") {
            if #available(macOS 26.0, iOS 26.0, *) {
                let status = AppleFoundationIntrospection.checkAvailability()
                HStack(spacing: 8) {
                    Circle()
                        .fill(status.isAvailable ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(status.description)
                        .foregroundStyle(status.isAvailable ? .primary : .secondary)
                }

                if status.isAvailable {
                    Label("All processing happens on-device. Your data never leaves your Mac.", systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !status.isAvailable {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Apple Intelligence must be enabled in System Settings → Apple Intelligence & Siri.", systemImage: "gear")
                        Label("Requires a Mac with Apple Silicon (M1 or later).", systemImage: "cpu")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } else {
                Label("Apple Intelligence requires macOS 26.0 or later.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
        }

        Section("About On-Device Model") {
            VStack(alignment: .leading, spacing: 6) {
                Label("~4,096 token context window (shorter conversations)", systemImage: "text.badge.minus")
                Label("No reasoning/thinking mode", systemImage: "brain")
                Label("Tool calling via prompt instructions", systemImage: "wrench.and.screwdriver")
                Label("No image/vision support", systemImage: "photo")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Ollama Components

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

    // MARK: - Shared Components

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

    @ViewBuilder
    private var imageInputRow: some View {
        let hasVision = store.capabilities?.hasVision ?? false
        if hasVision {
            Toggle("Use LLM Vision capabilities", isOn: $settings.useLLMVision)
            Text(settings.useLLMVision
                 ? "Images are sent directly to the model for visual analysis."
                 : "Images are recognised on-device with Apple Vision and sent as text.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            HStack {
                Label("Image input", systemImage: "text.viewfinder")
                Spacer()
                Text("System OCR")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
                    .foregroundStyle(.secondary)
            }
            Text("Vision is unavailable. Images will be OCR'd on-device with Apple Vision and sent as text.")
                .font(.caption)
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
            Toggle("Thinking", isOn: $settings.thinkingEnabled)
            Text(thinkingHelpText)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("The selected model does not support reasoning.")
                .foregroundStyle(.secondary)
        }
    }

    private var thinkingHelpText: String {
        if settings.ollamaModel.lowercased().contains("gpt-oss") {
            return "gpt-oss reasons at \"medium\" when on and can't be fully disabled (it falls back to \"low\")."
        }
        return "When on, the model includes a reasoning trace before answering. Turn off for faster, direct replies."
    }
}

