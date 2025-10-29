import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

final class HealthKitManager {
    #if canImport(HealthKit)
    private let healthStore = HKHealthStore()
    private let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    private let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
    private let exerciseTimeType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)!
    private let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
    #endif

    func isHealthDataAvailable() -> Bool {
        #if canImport(HealthKit)
        HKHealthStore.isHealthDataAvailable()
        #else
        return true
        #endif
    }

    func requestAuthorization() async throws -> Bool {
        #if canImport(HealthKit)
        let readTypes: Set = [stepType, activeEnergyType, exerciseTimeType, distanceType]
        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
        #else
        return true
        #endif
    }

    func enableBackgroundDelivery() {
        #if canImport(HealthKit)
        healthStore.enableBackgroundDelivery(for: stepType, frequency: .daily) { _, _ in }
        healthStore.enableBackgroundDelivery(for: activeEnergyType, frequency: .daily) { _, _ in }
        #endif
    }

    func fetchDailySummary(for date: Date) async throws -> DailyActivitySummary {
        #if canImport(HealthKit)
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            throw NSError(domain: "com.embrhealth.healthkit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to compute date range"])
        }
        async let stepCount = fetchCumulativeSum(for: stepType, unit: .count(), start: startOfDay, end: endOfDay)
        async let activeEnergy = fetchCumulativeSum(for: activeEnergyType, unit: .kilocalorie(), start: startOfDay, end: endOfDay)
        async let exerciseMinutes = fetchCumulativeSum(for: exerciseTimeType, unit: .minute(), start: startOfDay, end: endOfDay)
        async let distance = fetchCumulativeSum(for: distanceType, unit: .meter(), start: startOfDay, end: endOfDay)
        let stepsValue = Int(try await stepCount.rounded())
        let energyValue = try await activeEnergy
        let exerciseValue = Int(try await exerciseMinutes.rounded())
        let distanceMeters = try await distance
        return DailyActivitySummary(
            steps: stepsValue,
            activeEnergy: energyValue,
            exerciseMinutes: exerciseValue,
            distance: distanceMeters > 0 ? distanceMeters / 1000 : nil
        )
        #else
        return DailyActivitySummary(steps: 8750, activeEnergy: 520, exerciseMinutes: 42, distance: 6.2)
        #endif
    }

    #if canImport(HealthKit)
    private func fetchCumulativeSum(for type: HKQuantityType, unit: HKUnit, start: Date, end: Date) async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let quantity = statistics?.sumQuantity() {
                    continuation.resume(returning: quantity.doubleValue(for: unit))
                } else {
                    continuation.resume(returning: 0)
                }
            }
            healthStore.execute(query)
        }
    }
    #endif
}
