import Foundation

enum DictationState: Equatable {
    case idle
    case preparing
    case recording
    case finalizing
    case refining
    case inserting
    case error(String)

    var title: String {
        switch self {
        case .idle: "Ready"
        case .preparing: "Getting ready…"
        case .recording: "Listening…"
        case .finalizing: "Transcribing…"
        case .refining: "Cleaning up…"
        case .inserting: "Inserting…"
        case .error: "Something went wrong"
        }
    }

    var symbol: String {
        switch self {
        case .idle: "waveform"
        case .preparing, .finalizing, .refining, .inserting: "ellipsis"
        case .recording: "waveform.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        }
    }

    var isBusy: Bool {
        switch self {
        case .idle, .error: false
        default: true
        }
    }
}
