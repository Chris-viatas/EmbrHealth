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
        ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
    }

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
        You are EmbrHealth Coach, an empathetic health and wellness assistant. Provide educational, non-diagnostic guidance grounded in the supplied activity, heart rate, sleep, and VO₂ max summaries. Encourage healthy habits, hydration, recovery, and consult-a-professional language. Never store or request personally identifiable information and never discuss topics unrelated to personal wellness.
        """

        var messagesPayload: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "system", "content": "Context summary:\n\(snapshot.sanitizedContext())"]
        ]

        scrubbedHistory.forEach { message in
            let role = message.sender == .user ? "user" : "assistant"
            messagesPayload.append(["role": role, "content": message.text])
        }

        messagesPayload.append(["role": "user", "content": scrubbedInput])

        let payload = ChatPayload(model: "gpt-4.1-mini", messages: messagesPayload)
        let requestData = try JSONEncoder().encode(payload)

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = requestData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ServiceError.invalidResponse
            }
            guard httpResponse.statusCode == 200 else {
                let message = String(data: data, encoding: .utf8) ?? "Unexpected error"
                throw ServiceError.networkFailure(message)
            }
            let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
            if let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty {
                return content
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

private struct ChatPayload: Encodable {
    let model: String
    let messages: [[String: String]]
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}
