import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ChatAttachment: Identifiable, Equatable {
    let id = UUID()
    let base64: String
    let image: NSImage
}

@MainActor
@Observable
final class ChatComposerModel {
    var attachments: [ChatAttachment] = []

    func addImageData(_ data: Data) {
        guard let img = NSImage(data: data) else { return }
        attachments.append(ChatAttachment(base64: data.base64EncodedString(), image: img))
    }

    func addImage(_ image: NSImage) {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        attachments.append(ChatAttachment(base64: png.base64EncodedString(), image: image))
    }

    func remove(_ attachment: ChatAttachment) {
        attachments.removeAll { $0.id == attachment.id }
    }

    func clear() {
        attachments.removeAll()
    }
}

struct ChatView: View {
    @State var service: ChatService
    @Bindable var settings: AppSettings
    let store: ModelCapabilityStore
    @State private var draft: String = ""
    @State private var showSettings = false
    @State private var requestInputFocus: Bool = false
    @State private var composer = ChatComposerModel()
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    if isEmptyState {
                        ChatSuggestionsView(suggestions: ChatSuggestion.defaults) { s in
                            handleSuggestion(s)
                        }
                        .frame(minHeight: 420)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            let results = toolResultsMap()
                            ForEach(Array(visibleMessages().enumerated()), id: \.offset) { idx, msg in
                                MessageBubbleView(message: msg, toolResults: results)
                                    .id(idx)
                            }
                            if !service.streamingAssistantText.isEmpty {
                                MessageBubbleView(message: LLMMessage(
                                    role: .assistant,
                                    content: service.streamingAssistantText
                                ))
                                .id("streaming")
                            }
                            if showTypingIndicator {
                                TypingIndicator().id("typing")
                            }
                            if let confirm = service.pendingConfirmation {
                                ToolConfirmView(
                                    request: confirm,
                                    onApprove: { Task { await service.approve(confirm) } },
                                    onReject: { Task { await service.reject(confirm) } }
                                )
                                .id("confirm")
                            }
                        }
                        .padding()
                    }
                }
                .onChange(of: service.messages.count) { _, _ in
                    withAnimation { proxy.scrollTo(service.messages.count - 1, anchor: .bottom) }
                }
                .onChange(of: service.streamingAssistantText) { _, _ in
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
                .onChange(of: service.isBusy) { _, busy in
                    if busy { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
                }
            }
            Divider()
            if store.toolsUnsupported {
                toolsWarningBar
            }
            inputBar
            if let err = service.errorMessage {
                Text(err).foregroundStyle(.red).padding(8)
            }
        }
        .navigationTitle("Chatbot")
        .toolbar {
            ToolbarItemGroup {
                HStack(spacing: 4) {
                    Image(systemName: settings.provider.icon)
                        .font(.caption2)
                    Text(settings.provider.displayName)
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.ultraThinMaterial, in: .capsule)
                .foregroundStyle(.secondary)

                Button {
                    service.reset()
                } label: {
                    Label("New Chat", systemImage: "square.and.pencil")
                }
                .help("Start a fresh chat (clears the conversation)")
                Button {
                    showSettings = true
                } label: {
                    Label("Chat Settings", systemImage: "gearshape")
                }
                .help("Configure LLM provider, model, and tool permissions")
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                LLMSettingsView(settings: settings, store: store)
                    .navigationTitle("Chat Settings")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showSettings = false }
                                .help("Close chat settings")
                        }
                    }
            }
            .frame(minWidth: 480, minHeight: 420)
        }
        .onAppear { requestInputFocus = true }
        .task { await store.loadCapabilities() }
        .onDrop(of: [.image, .fileURL], isTargeted: $isDropTargeted) { providers in
            handleProviders(providers)
        }
    }

    private var toolsWarningBar: some View {
        let modelName = settings.provider == .ollama ? "\"\(settings.ollamaModel)\"" : settings.provider.displayName
        return Label("\(modelName) does not support tool calling. Pick a tool-capable model in Chat Settings to send messages.", systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.1))
    }

    private var inputBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !composer.attachments.isEmpty {
                attachmentsRow
            }
            HStack(spacing: 8) {
                if store.hasVision {
                    Button(action: pickImages) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 16))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .help("Attach images for this vision model")
                }
                SpellCheckedTextField(
                    text: $draft,
                    focusRequest: $requestInputFocus,
                    placeholder: "Message",
                    maxLines: 5,
                    onSubmit: sendDraft,
                    onImageData: { composer.addImageData($0) }
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(.background.secondary)
                )
                .overlay(
                    Capsule().stroke(isDropTargeted ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: isDropTargeted ? 1.5 : 0.5)
                )

                Button(action: sendDraft) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle().fill(canSend ? Color.accentColor : Color.secondary.opacity(0.4))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var attachmentsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(composer.attachments) { att in
                    ZStack(alignment: .topTrailing) {
                        Image(nsImage: att.image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Button {
                            composer.remove(att)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white, .black.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .padding(2)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(height: 60)
    }

    private var canSend: Bool {
        guard !service.isBusy else { return false }
        guard !store.toolsUnsupported else { return false }
        return !draft.trimmingCharacters(in: .whitespaces).isEmpty || !composer.attachments.isEmpty
    }

    private func sendDraft() {
        guard canSend else { return }
        let toSend = draft
        let images = composer.attachments.map(\.base64)
        draft = ""
        composer.clear()
        Task { await service.send(userText: toSend, images: images) }
    }

    private func pickImages() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let data = try? Data(contentsOf: url) {
                composer.addImageData(data)
            }
        }
    }

    @discardableResult
    private func handleProviders(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.canLoadObject(ofClass: NSImage.self) {
                handled = true
                _ = provider.loadObject(ofClass: NSImage.self) { obj, _ in
                    guard let img = obj as? NSImage else { return }
                    Task { @MainActor in composer.addImage(img) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                handled = true
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil),
                          let fileData = try? Data(contentsOf: url) else { return }
                    Task { @MainActor in composer.addImageData(fileData) }
                }
            }
        }
        return handled
    }

    private var showTypingIndicator: Bool {
        service.isBusy
            && service.streamingAssistantText.isEmpty
            && service.pendingConfirmation == nil
    }

    private func visibleMessages() -> [LLMMessage] {
        service.messages.filter { $0.role != .system && $0.role != .tool }
    }

    private var isEmptyState: Bool {
        visibleMessages().isEmpty
            && service.streamingAssistantText.isEmpty
            && service.pendingConfirmation == nil
            && !service.isBusy
    }

    private func handleSuggestion(_ s: ChatSuggestion) {
        draft = s.prompt
        requestInputFocus = true
    }

    private func toolResultsMap() -> [String: LLMMessage] {
        var map: [String: LLMMessage] = [:]
        for msg in service.messages where msg.role == .tool {
            if let id = msg.toolCallId { map[id] = msg }
        }
        return map
    }
}
