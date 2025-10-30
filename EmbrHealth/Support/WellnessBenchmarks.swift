import Foundation

enum WellnessBenchmarks {
    /// Approximate VO₂ max range (ml/kg·min) for moderately active adults (ACSM guidelines).
    static let vo2HealthyRange: ClosedRange<Double> = 35...52

    /// Recommended nightly sleep duration in hours (CDC adult guidance).
    static let recommendedSleepHours: ClosedRange<Double> = 7...9

    /// Typical resting heart rate band for healthy adults (beats per minute).
    static let restingHeartRateRange: ClosedRange<Double> = 60...100
}
