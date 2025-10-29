import Charts
import SwiftData
import SwiftUI

struct TrendsView: View {
    @Query(sort: \HealthMetric.date, order: .reverse, animation: .default)
    private var metrics: [HealthMetric]

    @Query(sort: \Workout.date, order: .reverse, animation: .default)
    private var workouts: [Workout]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                activityChartSection
                energyChartSection
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
                Chart(metrics.sorted(by: { $0.date < $1.date })) { metric in
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
                Chart(metrics.sorted(by: { $0.date < $1.date })) { metric in
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
                .frame(height: 200)
                .chartLegend(position: .bottom)
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

private struct WorkoutRow: View {
    let workout: Workout

    private var durationFormatter: DateComponentsFormatter {
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
