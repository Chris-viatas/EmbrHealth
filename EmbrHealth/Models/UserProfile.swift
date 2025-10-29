import Foundation
import SwiftData

@Model
final class UserProfile {
    var givenName: String
    var age: Int?
    var height: Double?
    var weight: Double?
    var gender: String?
    var primaryGoal: GoalCategory
    var prefersNotifications: Bool
    var onboardingCompletedAt: Date?

    init(
        givenName: String = "",
        age: Int? = nil,
        height: Double? = nil,
        weight: Double? = nil,
        gender: String? = nil,
        primaryGoal: GoalCategory = .steps,
        prefersNotifications: Bool = false,
        onboardingCompletedAt: Date? = nil
    ) {
        self.givenName = givenName
        self.age = age
        self.height = height
        self.weight = weight
        self.gender = gender
        self.primaryGoal = primaryGoal
        self.prefersNotifications = prefersNotifications
        self.onboardingCompletedAt = onboardingCompletedAt
    }
}
