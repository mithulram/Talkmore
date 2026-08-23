import Foundation
import Observation

enum WritingStyle: String, CaseIterable, Codable, Identifiable {
    case automatic
    case everyday
    case concise
    case email
    case developer
    case verbatim

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .everyday: "Everyday"
        case .concise: "Concise"
        case .email: "Email"
        case .developer: "Developer"
        case .verbatim: "Verbatim"
        }
    }

    var detail: String {
        switch self {
        case .automatic: "Adapts to email, coding, and everyday apps."
        case .everyday: "Natural punctuation and clean prose."
        case .concise: "Tighter phrasing with unnecessary words removed."
        case .email: "Professional paragraphs, greetings, and sign-offs."
        case .developer: "Technical names, filenames, symbols, and casing."
        case .verbatim: "Keeps your words with minimal intervention."
        }
    }

    var symbol: String {
        switch self {
        case .automatic: "wand.and.stars"
        case .everyday: "text.quote"
        case .concise: "arrow.down.right.and.arrow.up.left"
        case .email: "envelope"
        case .developer: "chevron.left.forwardslash.chevron.right"
        case .verbatim: "quote.opening"
        }
    }
}

enum DictationLanguage: String, CaseIterable, Codable, Identifiable {
    case automatic
    case englishUS = "en_US"
    case englishUK = "en_GB"
    case german = "de_DE"
    case french = "fr_FR"
    case spanish = "es_ES"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "Automatic (System)"
        case .englishUS: "English (US)"
        case .englishUK: "English (UK)"
        case .german: "German"
        case .french: "French"
        case .spanish: "Spanish"
        }
    }

    var locale: Locale {
        self == .automatic ? .current : Locale(identifier: rawValue)
    }
}

enum OverlayPlacement: String, CaseIterable, Codable, Identifiable {
    case bottom
    case center
    case top

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

@MainActor
@Observable
final class ProductSettings {
    var writingStyle: WritingStyle {
        didSet { defaults.set(writingStyle.rawValue, forKey: Keys.writingStyle) }
    }
    var dictationLanguage: DictationLanguage {
        didSet { defaults.set(dictationLanguage.rawValue, forKey: Keys.dictationLanguage) }
    }
    var showOverlay: Bool {
        didSet { defaults.set(showOverlay, forKey: Keys.showOverlay) }
    }
    var overlayPlacement: OverlayPlacement {
        didSet { defaults.set(overlayPlacement.rawValue, forKey: Keys.overlayPlacement) }
    }
    var saveHistory: Bool {
        didSet { defaults.set(saveHistory, forKey: Keys.saveHistory) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        writingStyle = WritingStyle(
            rawValue: defaults.string(forKey: Keys.writingStyle) ?? ""
        ) ?? .automatic
        dictationLanguage = DictationLanguage(
            rawValue: defaults.string(forKey: Keys.dictationLanguage) ?? ""
        ) ?? .automatic
        showOverlay = defaults.object(forKey: Keys.showOverlay) as? Bool ?? true
        overlayPlacement = OverlayPlacement(
            rawValue: defaults.string(forKey: Keys.overlayPlacement) ?? ""
        ) ?? .bottom
        saveHistory = defaults.object(forKey: Keys.saveHistory) as? Bool ?? true
    }

    private enum Keys {
        static let writingStyle = "product.writingStyle"
        static let dictationLanguage = "product.dictationLanguage"
        static let showOverlay = "product.showOverlay"
        static let overlayPlacement = "product.overlayPlacement"
        static let saveHistory = "product.saveHistory"
    }
}
