import Foundation

struct WellnessSnapshot {
    struct GoalStatus {
        let category: GoalCategory
        let completionRatio: Double
        let target: Double
    }

    struct WorkoutDigest {
        let totalDuration: TimeInterval
        let count: Int
        let calorieBurn: Double
        let predominantTypes: [String]
    }

    let observationWindowDays: Int
    let averageSteps: Int
    let averageActiveEnergy: Double
    let averageExerciseMinutes: Double
    let averageRestingHeartRate: Double?
    let averageMaxHeartRate: Double?
    let averageSleepHours: Double?
    let averageSleepEfficiency: Double?
    let averageVo2Max: Double?
    let goalStatuses: [GoalStatus]
    let workouts: WorkoutDigest

    func sanitizedContext() -> String {
        var lines: [String] = []
        if observationWindowDays > 0 {
            lines.append("Observation window: last \(observationWindowDays) days.")
        } else {
            lines.append("Observation window: insufficient recent data. Provide general guidance based on healthy habits.")
        }
        lines.append("Average daily steps: \(averageSteps).")
        lines.append("Average active energy burn: \(averageActiveEnergy.rounded()).")
        lines.append("Average exercise minutes: \(Int(averageExerciseMinutes.rounded())).")
        if let averageRestingHeartRate {
            lines.append("Resting heart rate average: \(Int(averageRestingHeartRate.rounded())) bpm.")
        }
        if let averageMaxHeartRate {
            lines.append("Peak heart rate average: \(Int(averageMaxHeartRate.rounded())) bpm.")
        }
        if let averageSleepHours {
            let hoursText = averageSleepHours.formatted(.number.precision(.fractionLength(1)))
            if let efficiency = averageSleepEfficiency {
                let percent = NumberFormatter.percent.string(from: NSNumber(value: efficiency)) ?? ""
                lines.append("Average sleep duration: \(hoursText) hours with \(percent) efficiency.")
            } else {
                lines.append("Average sleep duration: \(hoursText) hours.")
            }
        }
        if let averageVo2Max {
            lines.append("Average VO₂ max: \(averageVo2Max.formatted(.number.precision(.fractionLength(1)))) ml/kg·min.")
        }

        if !goalStatuses.isEmpty {
            let goalSummaries = goalStatuses.map { status in
                let percent = NumberFormatter.percent.string(from: NSNumber(value: min(max(status.completionRatio, 0), 1))) ?? ""
                return "\(status.category.name) goals are \(percent) of \(status.target.formatted(.number.precision(.fractionLength(0)))) target."
            }
            lines.append(contentsOf: goalSummaries)
        }

        let workoutMinutes = Int(workouts.totalDuration / 60)
        lines.append("Workouts completed: \(workouts.count) sessions totalling \(workoutMinutes) minutes and \(Int(workouts.calorieBurn.rounded())) kcal. Predominant types: \(workouts.predominantTypes.joined(separator: ", ")).")

        lines.append("Never disclose personal identifiers. Focus on wellness education, habit formation, recovery guidance, and actionable insights within scope.")

        return lines.joined(separator: "\n")
    }
}

struct WellnessSummaryBuilder {
    func snapshot(metrics: [HealthMetric], goals: [Goal], workouts: [Workout]) -> WellnessSnapshot {
        let observationWindow = metrics.isEmpty ? 0 : max(cappedMetrics.count, 1)
        let cappedMetrics = Array(metrics.sorted(by: { $0.date > $1.date }).prefix(30))
        let stepAverage = cappedMetrics.map { Double($0.stepCount) }.averageValue()
        let energyAverage = cappedMetrics.map(\.activeEnergy).averageValue()
        let exerciseAverage = cappedMetrics.map { Double($0.activeMinutes) }.averageValue()
        let restingAverage = cappedMetrics.compactMap(\.restingHeartRate).averageOrNil()
        let maxAverage = cappedMetrics.compactMap(\.maxHeartRate).averageOrNil()
        let sleepAverage = cappedMetrics.compactMap(\.sleepHours).averageOrNil()
        let sleepEfficiencyAverage = cappedMetrics.compactMap(\.sleepEfficiency).averageOrNil()
        let vo2Average = cappedMetrics.compactMap(\.vo2Max).averageOrNil()

        let goalStatuses: [WellnessSnapshot.GoalStatus] = goals.filter { !$0.isArchived }.map { goal in
            WellnessSnapshot.GoalStatus(
                category: goal.category,
                completionRatio: goal.targetValue > 0 ? goal.progressValue / goal.targetValue : 0,
                target: goal.targetValue
            )
        }

        let recentWorkouts = workouts.filter { workout in
            guard let earliest = cappedMetrics.last?.date else { return true }
            return workout.date >= earliest
        }

        let totalDuration = recentWorkouts.reduce(0) { $0 + $1.duration }
        let totalCalories = recentWorkouts.reduce(0) { $0 + $1.caloriesBurned }
        let predominantTypes = Array(Dictionary(grouping: recentWorkouts, by: \.type)
            .mapValues { Double($0.count) }
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map(\.key))

        let workoutDigest = WellnessSnapshot.WorkoutDigest(
            totalDuration: totalDuration,
            count: recentWorkouts.count,
            calorieBurn: totalCalories,
            predominantTypes: predominantTypes.isEmpty ? ["General"] : predominantTypes
        )

        return WellnessSnapshot(
            observationWindowDays: observationWindow,
            averageSteps: Int(stepAverage.rounded()),
            averageActiveEnergy: energyAverage,
            averageExerciseMinutes: exerciseAverage,
            averageRestingHeartRate: restingAverage,
            averageMaxHeartRate: maxAverage,
            averageSleepHours: sleepAverage,
            averageSleepEfficiency: sleepEfficiencyAverage,
            averageVo2Max: vo2Average,
            goalStatuses: goalStatuses,
            workouts: workoutDigest
        )
    }
}

private extension Sequence where Element == Double {
    func averageValue() -> Double {
        let values = Array(self)
        guard !values.isEmpty else { return 0 }
        let total = values.reduce(0, +)
        return total / Double(values.count)
    }

    func averageOrNil() -> Double? {
        let values = Array(self)
        guard !values.isEmpty else { return nil }
        let total = values.reduce(0, +)
        return total / Double(values.count)
    }
}

private extension Sequence where Element == Int {
    func averageValue() -> Double {
        let values = Array(self)
        guard !values.isEmpty else { return 0 }
        let total = values.reduce(0, +)
        return Double(total) / Double(values.count)
    }
}

private extension NumberFormatter {
    static let percent: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}
