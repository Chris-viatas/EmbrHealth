import Foundation
import SwiftData

@Model
final class Goal {
    var title: String
    var category: GoalCategory
    var targetValue: Double
    var progressValue: Double
    var deadline: Date?
    var createdAt: Date
    var isArchived: Bool

    init(
        title: String,
        category: GoalCategory,
        targetValue: Double,
        progressValue: Double = 0,
        deadline: Date? = nil,
        createdAt: Date = .now,
        isArchived: Bool = false
    ) {
        self.title = title
        self.category = category
        self.targetValue = targetValue
        self.progressValue = progressValue
        self.deadline = deadline
        self.createdAt = createdAt
        self.isArchived = isArchived
    }

    var completionRatio: Double {
        guard targetValue > 0 else { return 0 }
        return min(progressValue / targetValue, 1)
    }
}
