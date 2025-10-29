import Foundation
import SwiftData

@Model
final class HealthMetric {
    var date: Date
    var stepCount: Int
    var activeEnergy: Double
    var activeMinutes: Int
    var distance: Double?
    var restingHeartRate: Double?
    var sleepHours: Double?
    var lastUpdatedAt: Date

    init(
        date: Date,
        stepCount: Int,
        activeEnergy: Double,
        activeMinutes: Int,
        distance: Double? = nil,
        restingHeartRate: Double? = nil,
        sleepHours: Double? = nil,
        lastUpdatedAt: Date = .now
    ) {
        self.date = date
        self.stepCount = stepCount
        self.activeEnergy = activeEnergy
        self.activeMinutes = activeMinutes
        self.distance = distance
        self.restingHeartRate = restingHeartRate
        self.sleepHours = sleepHours
        self.lastUpdatedAt = lastUpdatedAt
    }
}
