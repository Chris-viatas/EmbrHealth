import Foundation
import SwiftData

enum PreviewSampleData {
    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            HealthMetric.self,
            Goal.self,
            Workout.self,
            UserProfile.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        Task { @MainActor in
            let context = container.mainContext
            seedMetrics(in: context)
            seedGoals(in: context)
            seedWorkouts(in: context)
        }
        return container
    }

    @MainActor
    private static func seedMetrics(in context: ModelContext) {
        let calendar = Calendar.current
        for dayOffset in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: .now) {
                let metric = HealthMetric(
                    date: calendar.startOfDay(for: date),
                    stepCount: Int.random(in: 6_000...13_000),
                    activeEnergy: Double.random(in: 350...650),
                    activeMinutes: Int.random(in: 20...60),
                    distance: Double.random(in: 3.5...8.5),
                    lastUpdatedAt: .now
                )
                context.insert(metric)
            }
        }
        try? context.save()
    }

    @MainActor
    private static func seedGoals(in context: ModelContext) {
        GoalCategory.allCases.forEach { category in
            let goal = Goal(
                title: "Weekly \(category.name) Goal",
                category: category,
                targetValue: category.defaultTarget,
                progressValue: category.defaultTarget * Double.random(in: 0.4...0.9)
            )
            context.insert(goal)
        }
        try? context.save()
    }

    @MainActor
    private static func seedWorkouts(in context: ModelContext) {
        let calendar = Calendar.current
        for offset in 0..<5 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: .now) else { continue }
            let workout = Workout(
                date: date,
                duration: TimeInterval.random(in: 1_800...4_200),
                caloriesBurned: Double.random(in: 250...600),
                type: ["Run", "Walk", "Strength", "Yoga", "Cycling"].randomElement() ?? "Workout",
                notes: Bool.random() ? "Felt great today!" : nil
            )
            context.insert(workout)
        }
        try? context.save()
    }
}
