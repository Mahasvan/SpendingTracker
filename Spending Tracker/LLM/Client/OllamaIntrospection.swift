import Foundation

struct ModelCapabilities: Sendable, Equatable {
    var hasTools: Bool
    var hasVision: Bool
    var hasThinking: Bool

    static let none = ModelCapabilities(hasTools: false, hasVision: false, hasThinking: false)
}

struct OllamaIntrospection: Sendable {
    let baseURL: URL
    let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func listModels() async throws -> [String] {
        let url = baseURL.appendingPathComponent("api/tags")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        let (data, resp) = try await fetch(req)
        try ensureOK(resp, data)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = obj["models"] as? [[String: Any]] else {
            return []
        }
        return models.compactMap { $0["name"] as? String }.sorted()
    }

    func capabilities(model: String) async throws -> ModelCapabilities {
        let url = baseURL.appendingPathComponent("api/show")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["model": model])
        let (data, resp) = try await fetch(req)
        try ensureOK(resp, data)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.decoding("Top-level not object")
        }
        let caps = (obj["capabilities"] as? [String]) ?? []
        let set = Set(caps.map { $0.lowercased() })
        return ModelCapabilities(
            hasTools: set.contains("tools"),
            hasVision: set.contains("vision"),
            hasThinking: set.contains("thinking")
        )
    }

    private func fetch(_ req: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: req)
        } catch {
            throw LLMError.transport(error)
        }
    }

    private func ensureOK(_ resp: URLResponse, _ data: Data) throws {
        guard let http = resp as? HTTPURLResponse else {
            throw LLMError.transport(URLError(.badServerResponse))
        }
        guard (200..<300).contains(http.statusCode) else {
            throw LLMError.badStatus(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
    }
}
