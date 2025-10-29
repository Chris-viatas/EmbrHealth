import Foundation
import SwiftData

@Model
final class Workout {
    var date: Date
    var duration: TimeInterval
    var caloriesBurned: Double
    var type: String
    var notes: String?

    init(
        date: Date,
        duration: TimeInterval,
        caloriesBurned: Double,
        type: String,
        notes: String? = nil
    ) {
        self.date = date
        self.duration = duration
        self.caloriesBurned = caloriesBurned
        self.type = type
        self.notes = notes
    }
}
