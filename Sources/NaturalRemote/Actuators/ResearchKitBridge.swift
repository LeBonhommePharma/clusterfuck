import Foundation
import BonhommeCore

#if canImport(ResearchKit)
import ResearchKit
#endif

// MARK: - Survey instrument catalog (PV / dose-effect)

public enum ResearchKitInstrument: String, Codable, Sendable, CaseIterable {
    /// Current subjective state after dose (0–10 intensity).
    case currentStateLog = "current-state-log"
    /// Dose-effect rating (1–5 Likert).
    case doseEffectRating = "dose-effect-rating"
    /// Pain VAS (0–10).
    case painVAS = "pain-vas"
    /// Mood Likert (1–5).
    case moodLikert = "mood-likert"
    /// WHO-5 well-being (0–25 raw).
    case wellBeing5 = "well-being-5"

    public var defaultScale: ClosedRange<Double> {
        switch self {
        case .currentStateLog, .painVAS: return 0...10
        case .doseEffectRating, .moodLikert: return 1...5
        case .wellBeing5: return 0...25
        }
    }
}

/// Result of a ResearchKit-style survey completion (framework-agnostic).
public struct ResearchKitSurveyResult: Codable, Sendable, Equatable {
    public var instrument: ResearchKitInstrument
    public var rawScore: Double
    public var normalizedScore: Double
    public var responses: [String: String]
    public var timestamp: Date

    public init(
        instrument: ResearchKitInstrument,
        rawScore: Double,
        normalizedScore: Double,
        responses: [String: String] = [:],
        timestamp: Date = Date()
    ) {
        self.instrument = instrument
        self.rawScore = rawScore
        self.normalizedScore = normalizedScore
        self.responses = responses
        self.timestamp = timestamp
    }

    /// Maps subjective score into a Crooks alexaEntropyHint-style contribution (higher distress → more work).
    public var crooksSubjectiveWorkHint: Double {
        // normalizedScore is "better" high for mood/WHO5; invert for work when instrument is distress-like.
        switch instrument {
        case .painVAS, .currentStateLog:
            return (1.0 - normalizedScore) * 0.5
        case .doseEffectRating:
            // Mid-scale = expected; extremes add work.
            return abs(normalizedScore - 0.5) * 0.4
        case .moodLikert, .wellBeing5:
            return (1.0 - normalizedScore) * 0.35
        }
    }
}

// MARK: - Bridge + RemoteActuator

/// ResearchKit integration for NATURaL Remote / pharmacovigilance.
///
/// - When ResearchKit is linked: builds ordered tasks for dose-effect / current-state surveys.
/// - Always: inject path for unit tests + FeedbackEngine `SurveySignal` ingestion.
/// - Registers on `ActuatorBus` as `.researchKit`.
public final class ResearchKitBridge: RemoteActuator, @unchecked Sendable {
    public let service: RemoteService = .researchKit

    private let lock = NSLock()
    private weak var feedbackEngine: FeedbackEngine?
    private var latestResults: [ResearchKitSurveyResult] = []
    private var pendingPromptInstrument: ResearchKitInstrument?

    public init(feedbackEngine: FeedbackEngine? = nil) {
        self.feedbackEngine = feedbackEngine
    }

    public func attachFeedbackEngine(_ engine: FeedbackEngine) {
        lock.lock()
        feedbackEngine = engine
        lock.unlock()
    }

    public var latestSurveyResults: [ResearchKitSurveyResult] {
        lock.lock(); defer { lock.unlock() }
        return latestResults
    }

    public var lastNormalizedScore: Double? {
        lock.lock(); defer { lock.unlock() }
        return latestResults.last?.normalizedScore
    }

    public var lastSubjectiveWorkHint: Double {
        lock.lock(); defer { lock.unlock() }
        return latestResults.last?.crooksSubjectiveWorkHint ?? 0
    }

    public var isPromptPending: Bool {
        lock.lock(); defer { lock.unlock() }
        return pendingPromptInstrument != nil
    }

    // MARK: - Inject / process (testable without ResearchKit binary)

    /// Primary entry used by Crooks/UI and tests — no ResearchKit required.
    @discardableResult
    public func injectSurvey(
        instrument: ResearchKitInstrument,
        rawScore: Double,
        responses: [String: String] = [:],
        at date: Date = Date()
    ) -> ResearchKitSurveyResult {
        let normalized = Self.normalize(rawScore: rawScore, instrument: instrument)
        var merged = responses
        merged["raw"] = String(format: "%.3f", rawScore)
        merged["normalized"] = String(format: "%.3f", normalized)

        let result = ResearchKitSurveyResult(
            instrument: instrument,
            rawScore: rawScore,
            normalizedScore: normalized,
            responses: merged,
            timestamp: date
        )

        lock.lock()
        latestResults.append(result)
        if latestResults.count > 200 {
            latestResults.removeFirst(latestResults.count - 200)
        }
        pendingPromptInstrument = nil
        let engine = feedbackEngine
        lock.unlock()

        let signal = SurveySignal(
            timestamp: date,
            instrumentId: instrument.rawValue,
            normalizedScore: normalized,
            responses: merged
        )
        engine?.ingest(signal)

        return result
    }

    public static func normalize(rawScore: Double, instrument: ResearchKitInstrument) -> Double {
        let range = instrument.defaultScale
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        let clamped = min(range.upperBound, max(range.lowerBound, rawScore))
        var n = (clamped - range.lowerBound) / span
        // Pain / intensity: invert so high raw pain → low normalized "wellness"
        switch instrument {
        case .painVAS, .currentStateLog:
            n = 1.0 - n
        case .doseEffectRating, .moodLikert, .wellBeing5:
            break
        }
        return min(1, max(0, n))
    }

    /// Apply last survey into multi-signal state for Crooks.
    ///
    /// Idempotent: assigns (does not accumulate) so repeated HRV ticks or a second
    /// `apply` cannot unbounded-grow `subjectiveWorkHint` or ratchet `sci`.
    /// SCI is always `0.5 * physiologicalSCI + 0.5 * lastNormalizedScore`.
    public func apply(to state: inout RemoteMultiSignalState) {
        state.subjectiveWorkHint = lastSubjectiveWorkHint
        if let score = lastNormalizedScore {
            let blended = state.physiologicalSCI * 0.5 + score * 0.5
            state.sci = min(1, max(0, blended))
        }
    }

    // MARK: - ResearchKit task descriptors (compile-safe)

    /// Describes a survey task. When ResearchKit is present, maps to ORKOrderedTask.
    public struct TaskDescriptor: Sendable, Equatable {
        public var instrument: ResearchKitInstrument
        public var title: String
        public var question: String
        public var minimum: Double
        public var maximum: Double
        public var stepIdentifier: String

        public init(instrument: ResearchKitInstrument) {
            self.instrument = instrument
            self.minimum = instrument.defaultScale.lowerBound
            self.maximum = instrument.defaultScale.upperBound
            self.stepIdentifier = instrument.rawValue + ".step"
            switch instrument {
            case .currentStateLog:
                self.title = "Current State"
                self.question = "Rate your current intensity / occupancy (0–10)."
            case .doseEffectRating:
                self.title = "Dose Effect"
                self.question = "How strong is the effect right now? (1–5)"
            case .painVAS:
                self.title = "Pain VAS"
                self.question = "Pain level (0–10)."
            case .moodLikert:
                self.title = "Mood"
                self.question = "Mood right now (1–5)."
            case .wellBeing5:
                self.title = "Well-being"
                self.question = "WHO-5 raw score (0–25)."
            }
        }
    }

    public func descriptor(for instrument: ResearchKitInstrument) -> TaskDescriptor {
        TaskDescriptor(instrument: instrument)
    }

    #if canImport(ResearchKit)
    /// Build a real ORKOrderedTask when ResearchKit is linked into the app target.
    public func makeOrderedTask(for instrument: ResearchKitInstrument) -> ORKOrderedTask {
        let d = descriptor(for: instrument)
        let answerFormat: ORKAnswerFormat
        switch instrument {
        case .currentStateLog, .painVAS:
            answerFormat = ORKAnswerFormat.scale(
                withMaximumValue: Int(d.maximum),
                minimumValue: Int(d.minimum),
                defaultValue: Int((d.minimum + d.maximum) / 2),
                step: 1,
                vertical: false,
                maximumValueDescription: "High",
                minimumValueDescription: "Low"
            )
        case .doseEffectRating, .moodLikert:
            answerFormat = ORKAnswerFormat.scale(
                withMaximumValue: 5,
                minimumValue: 1,
                defaultValue: 3,
                step: 1,
                vertical: false,
                maximumValueDescription: "Strong",
                minimumValueDescription: "None"
            )
        case .wellBeing5:
            answerFormat = ORKAnswerFormat.integerAnswerFormat(withUnit: nil)
        }
        let step = ORKQuestionStep(
            identifier: d.stepIdentifier,
            title: d.title,
            question: d.question,
            answer: answerFormat
        )
        return ORKOrderedTask(identifier: instrument.rawValue, steps: [step])
    }

    /// Parse ORKTaskResult into inject path (call from ORKTaskViewControllerDelegate).
    public func processTaskResult(_ taskResult: ORKTaskResult, instrument: ResearchKitInstrument) {
        var responses: [String: String] = [:]
        var raw = instrument.defaultScale.lowerBound
        if let stepResults = taskResult.results as? [ORKStepResult] {
            for step in stepResults {
                for r in step.results ?? [] {
                    if let scale = r as? ORKScaleQuestionResult, let v = scale.scaleAnswer?.doubleValue {
                        raw = v
                        responses[step.identifier] = String(format: "%.1f", v)
                    } else if let num = r as? ORKNumericQuestionResult, let v = num.numericAnswer?.doubleValue {
                        raw = v
                        responses[step.identifier] = String(format: "%.1f", v)
                    }
                }
            }
        }
        _ = injectSurvey(instrument: instrument, rawScore: raw, responses: responses)
    }
    #endif

    // MARK: - RemoteActuator

    public func execute(_ command: RemoteCommand) async throws {
        switch command.action {
        case "promptLog", "promptSurvey", "promptCurrentState":
            lock.lock()
            pendingPromptInstrument = .currentStateLog
            lock.unlock()
        case "promptDoseEffect":
            lock.lock()
            pendingPromptInstrument = .doseEffectRating
            lock.unlock()
        case "inject":
            let instRaw = command.params["instrument"] ?? ResearchKitInstrument.currentStateLog.rawValue
            let instrument = ResearchKitInstrument(rawValue: instRaw) ?? .currentStateLog
            let raw = Double(command.params["raw"] ?? command.params["score"] ?? "5") ?? 5
            _ = injectSurvey(instrument: instrument, rawScore: raw, responses: command.params)
        case "injectPainVAS":
            let raw = Double(command.params["score"] ?? "0") ?? 0
            _ = injectSurvey(instrument: .painVAS, rawScore: raw)
        case "injectMood":
            let raw = Double(command.params["score"] ?? "3") ?? 3
            _ = injectSurvey(instrument: .moodLikert, rawScore: raw)
        case "injectDoseEffect":
            let raw = Double(command.params["score"] ?? "3") ?? 3
            _ = injectSurvey(instrument: .doseEffectRating, rawScore: raw)
        default:
            if let inst = ResearchKitInstrument(rawValue: command.action) {
                let raw = Double(command.params["score"] ?? "5") ?? 5
                _ = injectSurvey(instrument: inst, rawScore: raw)
            }
        }
    }
}
