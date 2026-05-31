import Foundation
import SwiftData

@Model
final class ChatMessage {
    var id: UUID = UUID()
    var roleRaw: String = ChatRole.user.rawValue
    var content: String = ""
    var toolCallsJSON: String = ""
    var toolName: String = ""
    var toolCallId: String = ""
    var createdAt: Date = Date.now

    var session: ChatSession?

    var role: ChatRole {
        get { ChatRole(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        role: ChatRole,
        content: String,
        toolCallsJSON: String = "",
        toolName: String = "",
        toolCallId: String = "",
        session: ChatSession? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.roleRaw = role.rawValue
        self.content = content
        self.toolCallsJSON = toolCallsJSON
        self.toolName = toolName
        self.toolCallId = toolCallId
        self.session = session
        self.createdAt = createdAt
    }
}
