import Foundation

enum GoalCategory: String, Codable, CaseIterable, Identifiable {
    case steps
    case calories
    case workouts
    case sleep

    var id: String { rawValue }

    var name: String {
        switch self {
        case .steps:
            return "Steps"
        case .calories:
            return "Calories"
        case .workouts:
            return "Workouts"
        case .sleep:
            return "Sleep"
        }
    }

    var systemImageName: String {
        switch self {
        case .steps:
            return "figure.walk"
        case .calories:
            return "flame.fill"
        case .workouts:
            return "dumbbell"
        case .sleep:
            return "bed.double.fill"
        }
    }

    var defaultTarget: Double {
        switch self {
        case .steps:
            return 10_000
        case .calories:
            return 500
        case .workouts:
            return 3
        case .sleep:
            return 8
        }
    }

    var unitDescription: String {
        switch self {
        case .steps:
            return "steps"
        case .calories:
            return "kcal"
        case .workouts:
            return "sessions"
        case .sleep:
            return "hours"
        }
    }
}
