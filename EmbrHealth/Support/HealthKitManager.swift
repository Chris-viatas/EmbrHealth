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
    private let restingHeartRateType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
    private let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    private let vo2MaxType = HKQuantityType.quantityType(forIdentifier: .vo2Max)!
    private let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
    #endif

    func isHealthDataAvailable() -> Bool {
        #if canImport(HealthKit)
        return HKHealthStore.isHealthDataAvailable()
        #else
        return true
        #endif
    }

    func requestAuthorization() async throws -> Bool {
        #if canImport(HealthKit)
        let readTypes: Set = [
            stepType,
            activeEnergyType,
            exerciseTimeType,
            distanceType,
            restingHeartRateType,
            heartRateType,
            vo2MaxType,
            sleepType
        ]
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
        async let restingHeartRate = fetchDiscreteAverage(for: restingHeartRateType, unit: HKUnit.count().unitDivided(by: .minute()), start: startOfDay, end: endOfDay)
        async let maxHeartRate = fetchDiscreteMax(for: heartRateType, unit: HKUnit.count().unitDivided(by: .minute()), start: startOfDay, end: endOfDay)
        async let sleepMetrics = fetchSleepMetrics(start: startOfDay, end: endOfDay)
        async let vo2Max = fetchMostRecentQuantity(for: vo2MaxType, unit: HKUnit(from: "ml/(kg*min)"), start: startOfDay, end: endOfDay)
        let stepsValue = Int(try await stepCount.rounded())
        let energyValue = try await activeEnergy
        let exerciseValue = Int(try await exerciseMinutes.rounded())
        let distanceMeters = try await distance
        let sleepValue = try await sleepMetrics
        return DailyActivitySummary(
            steps: stepsValue,
            activeEnergy: energyValue,
            exerciseMinutes: exerciseValue,
            distance: distanceMeters > 0 ? distanceMeters / 1000 : nil,
            restingHeartRate: try await restingHeartRate,
            maxHeartRate: try await maxHeartRate,
            sleepHours: sleepValue.hours,
            sleepEfficiency: sleepValue.efficiency,
            vo2Max: try await vo2Max
        )
        #else
        return DailyActivitySummary(
            steps: 8750,
            activeEnergy: 520,
            exerciseMinutes: 42,
            distance: 6.2,
            restingHeartRate: 58,
            maxHeartRate: 148,
            sleepHours: 7.2,
            sleepEfficiency: 0.88,
            vo2Max: 41.0
        )
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

    private func fetchDiscreteAverage(for type: HKQuantityType, unit: HKUnit, start: Date, end: Date) async throws -> Double? {
        try await fetchStatistics(for: type, unit: unit, options: .discreteAverage, start: start, end: end)
    }

    private func fetchDiscreteMax(for type: HKQuantityType, unit: HKUnit, start: Date, end: Date) async throws -> Double? {
        try await fetchStatistics(for: type, unit: unit, options: .discreteMax, start: start, end: end)
    }

    private func fetchStatistics(for type: HKQuantityType, unit: HKUnit, options: HKStatisticsOptions, start: Date, end: Date) async throws -> Double? {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: options) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let quantity: HKQuantity?
                    if options.contains(.discreteAverage) {
                        quantity = statistics?.averageQuantity()
                    } else if options.contains(.discreteMax) {
                        quantity = statistics?.maximumQuantity()
                    } else if options.contains(.mostRecent) {
                        quantity = statistics?.mostRecentQuantity()
                    } else {
                        quantity = nil
                    }

                    if let quantity {
                        continuation.resume(returning: quantity.doubleValue(for: unit))
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
            healthStore.execute(query)
        }
    }

    private func fetchMostRecentQuantity(for type: HKQuantityType, unit: HKUnit, start: Date, end: Date) async throws -> Double? {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let quantitySample = samples?.first as? HKQuantitySample {
                    continuation.resume(returning: quantitySample.quantity.doubleValue(for: unit))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }

    private func fetchSleepMetrics(start: Date, end: Date) async throws -> (hours: Double?, efficiency: Double?) {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let categorySamples = samples as? [HKCategorySample], !categorySamples.isEmpty else {
                    continuation.resume(returning: (nil, nil))
                    return
                }

                var asleepSeconds: Double = 0
                var inBedSeconds: Double = 0

                for sample in categorySamples {
                    let duration = sample.endDate.timeIntervalSince(sample.startDate)
                    inBedSeconds += duration

                    let value = sample.value
                    if value == HKCategoryValueSleepAnalysis.asleep.rawValue {
                        asleepSeconds += duration
                    } else if #available(iOS 16.0, *) {
                        if value == HKCategoryValueSleepAnalysis.asleepREM.rawValue ||
                            value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                            value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue {
                            asleepSeconds += duration
                        }
                    }
                }

                let hours = asleepSeconds > 0 ? asleepSeconds / 3_600 : nil
                let efficiency: Double?
                if inBedSeconds > 0 {
                    efficiency = asleepSeconds / inBedSeconds
                } else {
                    efficiency = nil
                }

                continuation.resume(returning: (hours, efficiency))
            }
            healthStore.execute(query)
        }
    }
    #endif
}
