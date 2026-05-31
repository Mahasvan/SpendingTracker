import SwiftUI

struct LLMSettingsView: View {
    @Bindable var settings: AppSettings

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
                TextField("Model", text: $settings.ollamaModel)
                HStack {
                    Text("Temperature: \(String(format: "%.2f", settings.temperature))")
                    Slider(value: $settings.temperature, in: 0...1)
                }
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
    }
}
