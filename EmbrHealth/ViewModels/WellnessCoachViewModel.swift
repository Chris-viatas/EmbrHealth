import Combine
import Foundation
import SwiftData

@MainActor
final class WellnessCoachViewModel: ObservableObject {
    @Published private(set) var messages: [WellnessChatMessage] = []
    @Published private(set) var isProcessing = false
    @Published var errorMessage: String?

    private let aiService: WellnessAIService
    private let summaryBuilder: WellnessSummaryBuilder

    init(aiService: WellnessAIService? = nil, summaryBuilder: WellnessSummaryBuilder? = nil) {
        self.aiService = aiService ?? WellnessAIService()
        self.summaryBuilder = summaryBuilder ?? WellnessSummaryBuilder()
        bootstrap()
    }

    func bootstrap() {
        guard messages.isEmpty else { return }
        messages.append(
            WellnessChatMessage(
                sender: .coach,
                text: "Hi! I'm your EmbrHealth coach. Ask about your recent activity, heart trends, sleep recovery, or VO₂ max progress and I'll guide you with health-focused tips."
            )
        )
    }

    func send(_ text: String, metrics: [HealthMetric], goals: [Goal], workouts: [Workout]) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        errorMessage = nil
        let userMessage = WellnessChatMessage(sender: .user, text: trimmed)
        let history = messages
        messages.append(userMessage)
        isProcessing = true

        let snapshot = summaryBuilder.snapshot(metrics: metrics, goals: goals, workouts: workouts)

        do {
            let response = try await aiService.respond(to: trimmed, history: history, snapshot: snapshot)
            messages.append(WellnessChatMessage(sender: .coach, text: response))
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            messages.append(
                WellnessChatMessage(
                    sender: .coach,
                    text: "I'm sorry, I couldn't process that request. \(errorMessage ?? "Please try again later.")"
                )
            )
        }

        isProcessing = false
    }
}
