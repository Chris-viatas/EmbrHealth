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
    var maxHeartRate: Double?
    var sleepHours: Double?
    var sleepEfficiency: Double?
    var vo2Max: Double?
    var lastUpdatedAt: Date

    init(
        date: Date,
        stepCount: Int,
        activeEnergy: Double,
        activeMinutes: Int,
        distance: Double? = nil,
        restingHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        sleepHours: Double? = nil,
        sleepEfficiency: Double? = nil,
        vo2Max: Double? = nil,
        lastUpdatedAt: Date = .now
    ) {
        self.date = date
        self.stepCount = stepCount
        self.activeEnergy = activeEnergy
        self.activeMinutes = activeMinutes
        self.distance = distance
        self.restingHeartRate = restingHeartRate
        self.maxHeartRate = maxHeartRate
        self.sleepHours = sleepHours
        self.sleepEfficiency = sleepEfficiency
        self.vo2Max = vo2Max
        self.lastUpdatedAt = lastUpdatedAt
    }
}
