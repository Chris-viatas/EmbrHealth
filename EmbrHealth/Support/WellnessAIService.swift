import Foundation

struct WellnessAIService {
    enum ServiceError: LocalizedError {
        case guardrailViolation
        case networkFailure(String)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .guardrailViolation:
                return "Your message appears to include sensitive information. Please remove personal identifiers and try again."
            case .networkFailure(let message):
                return message
            case .invalidResponse:
                return "The wellness coach could not understand the response."
            }
        }
    }

    var apiKeyProvider: () -> String? = {
        if let envValue = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !envValue.isEmpty {
            return envValue
        }

        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String {
            let trimmed = plistValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        return nil
    }

    var urlSession: URLSession = .shared

    func respond(to userMessage: String, history: [WellnessChatMessage], snapshot: WellnessSnapshot) async throws -> String {
        guard HealthConversationGuard.allows(userMessage) else {
            throw ServiceError.guardrailViolation
        }

        let scrubbedHistory = history.suffix(10).map { message in
            WellnessChatMessage(sender: message.sender, text: HealthConversationGuard.scrub(message.text), timestamp: message.timestamp)
        }
        let scrubbedInput = HealthConversationGuard.scrub(userMessage)

        guard let apiKey = apiKeyProvider(), !apiKey.isEmpty else {
            return fallbackResponse(for: scrubbedInput, snapshot: snapshot)
        }

        let systemPrompt = """
        You are EmbrHealth, a personal health assistant and wellness coach. Provide educational personalized diagnostic guidance grounded in the supplied activity, heart rate, sleep, and VO₂ max summaries. Encourage healthy habits, exercise, hydration, recovery. Never store or request personally identifiable information and never discuss topics unrelated to personal health and wellness.
        """

        var inputMessages: [InputMessage] = [
            InputMessage(role: "system", content: [.text(systemPrompt)]),
            InputMessage(role: "system", content: [.text("Context summary:\n\(snapshot.sanitizedContext())")])
        ]

        scrubbedHistory.forEach { message in
            let role = message.sender == .user ? "user" : "assistant"
            inputMessages.append(InputMessage(role: role, content: [.text(message.text)]))
        }

        inputMessages.append(InputMessage(role: "user", content: [.text(scrubbedInput)]))

        let payload = ResponsesPayload(model: "gpt-4.1", input: inputMessages)
        let requestData = try JSONEncoder().encode(payload)

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = requestData

        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ServiceError.invalidResponse
            }
            guard httpResponse.statusCode == 200 else {
                let message = String(data: data, encoding: .utf8) ?? "Unexpected error"
                throw ServiceError.networkFailure(message)
            }
            let decoded = try JSONDecoder().decode(ResponsesCompletion.self, from: data)
            if let content = decoded.primaryOutputText?.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty {
                return content
            }
            if let fallbackText = decoded.concatenatedOutput?.trimmingCharacters(in: .whitespacesAndNewlines), !fallbackText.isEmpty {
                return fallbackText
            }
            throw ServiceError.invalidResponse
        } catch {
            if let serviceError = error as? ServiceError {
                switch serviceError {
                case .networkFailure, .invalidResponse:
                    return fallbackResponse(for: scrubbedInput, snapshot: snapshot)
                case .guardrailViolation:
                    throw serviceError
                }
            }
            return fallbackResponse(for: scrubbedInput, snapshot: snapshot)
        }
    }

    private func fallbackResponse(for _: String, snapshot: WellnessSnapshot) -> String {
        var lines: [String] = []
        lines.append("Here's a local summary while the network is offline:")
        lines.append("• Daily steps average: \(snapshot.averageSteps). Keep aiming for consistent movement across the week.")
        lines.append("• Active energy burn: \(Int(snapshot.averageActiveEnergy.rounded())) kcal on average.")
        lines.append("• Exercise minutes: \(Int(snapshot.averageExerciseMinutes.rounded())) per day.")
        if let rhr = snapshot.averageRestingHeartRate {
            lines.append("• Resting heart rate averages \(Int(rhr.rounded())) bpm compared to the typical \(Int(WellnessBenchmarks.restingHeartRateRange.lowerBound))–\(Int(WellnessBenchmarks.restingHeartRateRange.upperBound)) bpm range.")
        }
        if let sleep = snapshot.averageSleepHours {
            lines.append("• Sleep averages \(sleep.formatted(.number.precision(.fractionLength(1)))) h versus the \(WellnessBenchmarks.recommendedSleepHours.lowerBound.formatted(.number.precision(.fractionLength(1))))–\(WellnessBenchmarks.recommendedSleepHours.upperBound.formatted(.number.precision(.fractionLength(1)))) h recommendation.")
        }
        if let vo2 = snapshot.averageVo2Max {
            lines.append("• VO₂ max trends around \(vo2.formatted(.number.precision(.fractionLength(1)))) ml/kg·min. Healthy range reference: \(Int(WellnessBenchmarks.vo2HealthyRange.lowerBound))–\(Int(WellnessBenchmarks.vo2HealthyRange.upperBound)).")
        }
        lines.append("Consider steady movement, balanced nutrition, hydration, and schedule recovery days. Reach out to a licensed professional for diagnoses or major changes.")
        return lines.joined(separator: "\n")
    }
}

private struct ResponsesPayload: Encodable {
    let model: String
    let input: [InputMessage]
}

private struct InputMessage: Encodable {
    let role: String
    let content: [MessageContent]

    struct MessageContent: Encodable {
        let type: String
        let text: String

        static func text(_ value: String) -> MessageContent {
            MessageContent(type: "input_text", text: value)
        }
    }

    init(role: String, content: [MessageContent]) {
        self.role = role
        self.content = content
    }
}

private struct ResponsesCompletion: Decodable {
    struct Output: Decodable {
        struct Content: Decodable {
            let type: String
            let text: String?
        }
        let content: [Content]
    }

    let output: [Output]
    let outputText: [String]?

    enum CodingKeys: String, CodingKey {
        case output
        case outputText = "output_text"
    }

    var primaryOutputText: String? {
        outputText?.joined()
    }

    var concatenatedOutput: String? {
        let combined = output
            .flatMap { $0.content }
            .compactMap { $0.text }
            .joined(separator: "\n")
        return combined.isEmpty ? nil : combined
    }
}
