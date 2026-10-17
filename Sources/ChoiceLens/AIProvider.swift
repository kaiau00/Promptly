import Foundation

enum AIProvider: String, CaseIterable {
    case minimax
    case openAI
    case anthropic

    var displayName: String {
        switch self {
        case .minimax: "MiniMax"
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        }
    }

    var defaultModel: String {
        switch self {
        case .minimax: "MiniMax-M3"
        case .openAI: "gpt-5-mini"
        case .anthropic: "claude-haiku-5-5"
        }
    }
}

enum ProviderStore {
    private static let selectedProviderKey = "selectedAIProvider"

    static var current: AIProvider {
        get {
            guard let value = UserDefaults.standard.string(forKey: selectedProviderKey),
                  let provider = AIProvider(rawValue: value)
            else { return .minimax }
            return provider
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: selectedProviderKey) }
    }
}
