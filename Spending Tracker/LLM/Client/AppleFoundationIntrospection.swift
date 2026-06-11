import Foundation
import FoundationModels

/// Checks Apple Intelligence availability and reports model capabilities.
@available(macOS 26.0, iOS 26.0, *)
enum AppleFoundationIntrospection {

    /// Describes the availability status of Apple Intelligence on this device.
    enum AvailabilityStatus: Sendable {
        case available
        case notEligible
        case notEnabled
        case notReady
        case unknown(String)

        var description: String {
            switch self {
            case .available:
                return "Apple Intelligence is ready"
            case .notEligible:
                return "This Mac does not support Apple Intelligence"
            case .notEnabled:
                return "Turn on Apple Intelligence in System Settings → Apple Intelligence & Siri"
            case .notReady:
                return "Apple Intelligence model is downloading or preparing…"
            case .unknown(let msg):
                return "Apple Intelligence is unavailable: \(msg)"
            }
        }

        var isAvailable: Bool {
            if case .available = self { return true }
            return false
        }
    }

    /// Checks whether Apple Intelligence is available on this device.
    static func checkAvailability() -> AvailabilityStatus {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return .available
        case .unavailable(.deviceNotEligible):
            return .notEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            return .notEnabled
        case .unavailable(.modelNotReady):
            return .notReady
        case .unavailable(let reason):
            return .unknown("\(reason)")
        }
    }

    /// Returns the capabilities of Apple's on-device model.
    ///
    /// - Tools: Supported via prompt-based bridging (tool schemas described in system prompt)
    /// - Vision: Not supported in initial implementation
    /// - Thinking: Not applicable for on-device model
    static func capabilities() -> ModelCapabilities {
        ModelCapabilities(
            hasTools: true,
            hasVision: false,
            hasThinking: false
        )
    }
}
