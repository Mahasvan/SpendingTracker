import Foundation
import SwiftData

@MainActor
protocol ChatRepository: AnyObject {
    func createSession(title: String) throws -> ChatSession
    func renameSession(id: UUID, title: String) throws
    func deleteSession(id: UUID) throws
    func findSession(id: UUID) throws -> ChatSession?
    func allSessions() throws -> [ChatSession]
    func append(_ message: ChatMessage, to session: ChatSession) throws
    func messages(in session: ChatSession) throws -> [ChatMessage]
}

@MainActor
final class SwiftDataChatRepository: ChatRepository {
    private let context: ModelContext

    init(context: ModelContext) { self.context = context }

    func createSession(title: String = "New Chat") throws -> ChatSession {
        let session = ChatSession(title: title)
        context.insert(session)
        try context.save()
        return session
    }

    func renameSession(id: UUID, title: String) throws {
        guard let s = try findSession(id: id) else {
            throw RepositoryError.notFound("ChatSession \(id)")
        }
        s.title = title
        s.updatedAt = .now
        try context.save()
    }

    func deleteSession(id: UUID) throws {
        guard let s = try findSession(id: id) else {
            throw RepositoryError.notFound("ChatSession \(id)")
        }
        context.delete(s)
        try context.save()
    }

    func findSession(id: UUID) throws -> ChatSession? {
        var d = FetchDescriptor<ChatSession>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return try context.fetch(d).first
    }

    func allSessions() throws -> [ChatSession] {
        let d = FetchDescriptor<ChatSession>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        return try context.fetch(d)
    }

    func append(_ message: ChatMessage, to session: ChatSession) throws {
        message.session = session
        context.insert(message)
        session.updatedAt = .now
        try context.save()
    }

    func messages(in session: ChatSession) throws -> [ChatMessage] {
        let sid = session.id
        let d = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.session?.id == sid },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try context.fetch(d)
    }
}
