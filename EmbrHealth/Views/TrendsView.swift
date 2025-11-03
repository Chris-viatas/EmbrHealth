import Charts
import SwiftData
import SwiftUI

struct TrendsView: View {
    @Query(sort: \HealthMetric.date, order: .reverse, animation: .default)
    private var metrics: [HealthMetric]

    @Query(sort: \Workout.date, order: .reverse, animation: .default)
    private var workouts: [Workout]

    private var ascendingMetrics: [HealthMetric] {
        metrics.sorted(by: { $0.date < $1.date })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                activityChartSection
                energyChartSection
                heartRateSection
                sleepSection
                vo2Section
                workoutHistorySection
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .navigationTitle("Trends")
    }

    private var activityChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Steps & Distance", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)
            if metrics.isEmpty {
                ContentUnavailableView("No activity yet", systemImage: "shoeprints.fill", description: Text("Start moving to build your history."))
            } else {
                let orderedMetrics = ascendingMetrics
                Chart {
                    ForEach(orderedMetrics, id: \.date) { metric in
                let orderedMetrics = metrics.chronologicallyAscending
                Chart {
                    ForEach(Array(orderedMetrics.enumerated()), id: \.offset) { _, metric in
                        BarMark(
                            x: .value("Date", metric.date, unit: .day),
                            y: .value("Steps", metric.stepCount)
                        )
                        .foregroundStyle(.teal.gradient)
                        if let distance = metric.distance {
                            LineMark(
                                x: .value("Date", metric.date, unit: .day),
                                y: .value("Distance", distance)
                            )
                            .foregroundStyle(.orange)
                            .symbol(by: .value("Distance", "km"))
                        }
                    }
                }
                .frame(height: 220)
                .chartLegend(position: .bottom)
            }
        }
    }

    private var energyChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Energy & Active Minutes", systemImage: "flame")
                .font(.headline)
            if metrics.isEmpty {
                ContentUnavailableView("No energy data", systemImage: "bolt.fill", description: Text("Sync with Health to see your burn."))
            } else {
                let orderedMetrics = ascendingMetrics
                Chart {
                    ForEach(orderedMetrics, id: \.date) { metric in
                let orderedMetrics = metrics.chronologicallyAscending
                Chart {
                    ForEach(Array(orderedMetrics.enumerated()), id: \.offset) { _, metric in
                        AreaMark(
                            x: .value("Date", metric.date, unit: .day),
                            y: .value("Energy", metric.activeEnergy)
                        )
                        .foregroundStyle(.pink.gradient.opacity(0.7))
                        LineMark(
                            x: .value("Date", metric.date, unit: .day),
                            y: .value("Active Minutes", metric.activeMinutes)
                        )
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 6]))
                    }
                }
                .frame(height: 200)
                .chartLegend(position: .bottom)
            }
        }
    }

    private var heartRateSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Heart Rate", systemImage: "waveform.path.ecg")
                .font(.headline)
            if metrics.isEmpty {
                ContentUnavailableView("No heart rate data", systemImage: "heart.slash", description: Text("Grant access to Heart data to view resting and peak trends."))
            } else {
                Chart {
                    ForEach(Array(ascendingMetrics.enumerated()), id: \.offset) { _, metric in
                    ForEach(ascendingMetrics, id: \.date) { metric in
                    ForEach(Array(metrics.chronologicallyAscending.enumerated()), id: \.offset) { _, metric in
                        if let resting = metric.restingHeartRate {
                            LineMark(
                                x: .value("Date", metric.date, unit: .day),
                                y: .value("Resting", resting)
                            )
                            .foregroundStyle(by: .value("Series", "Resting"))
                            .interpolationMethod(.catmullRom)
                        }
                        if let max = metric.maxHeartRate {
                            LineMark(
                                x: .value("Date", metric.date, unit: .day),
                                y: .value("Max", max)
                            )
                            .foregroundStyle(by: .value("Series", "Peak"))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                }
                .frame(height: 200)
                .chartLegend(position: .bottom)
                .chartForegroundStyleScale([
                    "Resting": .green,
                    "Peak": .red
                ])
                Text("Resting heart rate between \(Int(WellnessBenchmarks.restingHeartRateRange.lowerBound))–\(Int(WellnessBenchmarks.restingHeartRateRange.upperBound)) bpm is typical for healthy adults. Consult a clinician for readings outside your norm.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var sleepSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Sleep Quality", systemImage: "bed.double")
                .font(.headline)
            if metrics.isEmpty {
                ContentUnavailableView("No sleep tracked", systemImage: "zzz", description: Text("Sleep data from Health will appear here."))
            } else {
                sleepChart
                sleepFooter
            }
        }
    }

    private var sleepChart: some View {
        let hourPoints = Array(ascendingMetrics.enumerated()).compactMap { (idx, m) -> (offset: Int, date: Date, hours: Double)? in
            guard let h = m.sleepHours else { return nil }
            return (offset: idx, date: m.date, hours: h)
        }
        let efficiencyPoints = Array(ascendingMetrics.enumerated()).compactMap { (idx, m) -> (offset: Int, date: Date, efficiencyPct: Double)? in
            guard let e = m.sleepEfficiency else { return nil }
            return (offset: idx, date: m.date, efficiencyPct: e * 100)
        }
        return Chart {
            ForEach(hourPoints, id: \.offset) { pt in
                BarMark(
                    x: .value("Date", pt.date, unit: .day),
                    y: .value("Hours", pt.hours)
                )
                .foregroundStyle(by: .value("Series", "Sleep Hours"))
            }
            ForEach(efficiencyPoints, id: \.offset) { pt in
                LineMark(
                    x: .value("Date", pt.date, unit: .day),
                    y: .value("Efficiency", pt.efficiencyPct)
                )
                .foregroundStyle(by: .value("Series", "Efficiency %"))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                if let percent = value.as(Double.self) {
                    AxisValueLabel("\(percent.formatted(.number.precision(.fractionLength(0))))%")
                Chart {
                    ForEach(ascendingMetrics, id: \.date) { metric in
                    ForEach(Array(metrics.chronologicallyAscending.enumerated()), id: \.offset) { _, metric in
                        if let hours = metric.sleepHours {
                            BarMark(
                                x: .value("Date", metric.date, unit: .day),
                                y: .value("Hours", hours)
                            )
                            .foregroundStyle(by: .value("Series", "Sleep Hours"))
                        }
                        if let efficiency = metric.sleepEfficiency {
                            LineMark(
                                x: .value("Date", metric.date, unit: .day),
                                y: .value("Efficiency", efficiency * 100)
                            )
                            .foregroundStyle(by: .value("Series", "Efficiency %"))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                            .position(by: .value("Axis", "Efficiency"))
                            .position(by: .value("Axis", "Efficiency"), axis: .trailing)
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartYAxis(.value("Axis", "Efficiency")) {
                    AxisMarks(position: .trailing) { value in
                .chartYAxis(position: .trailing) {
                    AxisMarks { value in
                        if let percent = value.as(Double.self) {
                            AxisValueLabel("\(percent.formatted(.number.precision(.fractionLength(0))))%")
                        }
                    }
                }
            }
        }
        .frame(height: 200)
        .chartLegend(position: .bottom)
        .chartForegroundStyleScale([
            "Sleep Hours": Color.indigo.opacity(0.7),
            "Efficiency %": .orange
        ])
    }

    private var sleepFooter: some View {
        Text("Target \(WellnessBenchmarks.recommendedSleepHours.lowerBound.formatted(.number.precision(.fractionLength(1))))–\(WellnessBenchmarks.recommendedSleepHours.upperBound.formatted(.number.precision(.fractionLength(1)))) hours per night for optimal recovery.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private var vo2Section: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("VO₂ Max", systemImage: "lungs")
                .font(.headline)
            if metrics.isEmpty {
                ContentUnavailableView("No VO₂ Max samples", systemImage: "lungs.slash", description: Text("Cardiorespiratory fitness readings appear once captured by your Apple Watch."))
            } else {
                Chart {
                    ForEach(Array(ascendingMetrics.enumerated()), id: \.offset) { _, metric in
                    ForEach(ascendingMetrics, id: \.date) { metric in
                    ForEach(Array(metrics.chronologicallyAscending.enumerated()), id: \.offset) { _, metric in
                        if let value = metric.vo2Max {
                            LineMark(
                                x: .value("Date", metric.date, unit: .day),
                                y: .value("VO₂", value)
                            )
                            .foregroundStyle(by: .value("Series", "VO₂ Max"))
                        }
                    }
                    RuleMark(y: .value("Healthy Minimum", WellnessBenchmarks.vo2HealthyRange.lowerBound))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                        .foregroundStyle(.gray)
                        .annotation(position: .leading) {
                            Text("Healthy min")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    RuleMark(y: .value("Healthy Upper", WellnessBenchmarks.vo2HealthyRange.upperBound))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                        .foregroundStyle(.gray.opacity(0.6))
                        .annotation(position: .trailing) {
                            Text("Healthy max")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                }
                .frame(height: 200)
                .chartLegend(position: .bottom)
                .chartForegroundStyleScale([
                    "VO₂ Max": .mint
                ])
                Text("Healthy VO₂ Max range is approximated for moderately active adults. Your optimal target may vary—discuss changes with a clinician.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var workoutHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Recent Workouts", systemImage: "figure.run")
                .font(.headline)
            if workouts.isEmpty {
                ContentUnavailableView("No workouts", systemImage: "figure.run", description: Text("Log a workout to see it here."))
            } else {
                ForEach(workouts.prefix(10)) { workout in
                    WorkoutRow(workout: workout)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }
}

struct WorkoutRow: View {
private struct WorkoutRow: View {
    let workout: Workout

    var durationFormatter: DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(workout.type)
                    .font(.headline)
                Spacer()
                Text(workout.date, format: .dateTime.month(.abbreviated).day().weekday(.wide))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Label(durationFormatter.string(from: workout.duration) ?? "—", systemImage: "timer")
                Label("\(workout.caloriesBurned.formatted(.number.precision(.fractionLength(0)))) kcal", systemImage: "flame.fill")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let notes = workout.notes, !notes.isEmpty {
                Text(notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        TrendsView()
    }
    .modelContainer(PreviewSampleData.makeContainer())
}
