import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var syncViewModel: HealthSyncViewModel

    @Query(sort: \HealthMetric.date, order: .reverse, animation: .default)
    private var metrics: [HealthMetric]

    @Query(filter: #Predicate<Goal> { !$0.isArchived }, sort: \Goal.createdAt, order: .forward, animation: .default)
    private var activeGoals: [Goal]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                dailyOverviewCard
                trendChart
                goalsPreview
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .navigationTitle("Dashboard")
        .task {
            await syncViewModel.syncTodayIfNeeded(with: context)
        }
        .refreshable {
            await syncViewModel.sync(for: Date(), context: context)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(greeting)
                .font(.title.bold())
            if syncViewModel.isSyncing {
                Label("Syncing with HealthKit…", systemImage: "arrow.clockwise")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if let lastSyncDate = syncViewModel.lastSyncDate {
                Label("Updated \(lastSyncDate, style: .time)", systemImage: "clock.arrow.circlepath")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Label("Tap to refresh Health data", systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let error = syncViewModel.lastSyncError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dailyOverviewCard: some View {
        Group {
            if let todayMetric = metrics.first(where: { Calendar.current.isDate($0.date, inSameDayAs: Date()) }) {
                MetricSummaryCard(metric: todayMetric)
            } else {
                ContentUnavailableView("No Health Data Yet", systemImage: "heart.circle", description: Text("Connect to Health to start tracking your day."))
            }
        }
    }

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("7-Day Activity", systemImage: "chart.bar.xaxis")
                    .font(.headline)
                Spacer()
            }
            Chart(lastSevenMetrics) { metric in
                BarMark(
                    x: .value("Date", metric.date, unit: .day),
                    y: .value("Steps", metric.stepCount)
                )
                .foregroundStyle(.blue.gradient)
                LineMark(
                    x: .value("Date", metric.date, unit: .day),
                    y: .value("Energy", metric.activeEnergy)
                )
                .foregroundStyle(.pink.gradient)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    if let date = value.as(Date.self) {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(date, format: .dateTime.weekday(.narrow))
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartLegend(position: .bottom, spacing: 12)
        }
    }

    private var goalsPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Active Goals", systemImage: "target")
                    .font(.headline)
                Spacer()
            }
            if activeGoals.isEmpty {
                ContentUnavailableView("No goals yet", systemImage: "target", description: Text("Set a goal to stay motivated."))
            } else {
                ForEach(activeGoals.prefix(3)) { goal in
                    GoalProgressRow(goal: goal)
                }
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        case 17..<22:
            return "Good evening"
        default:
            return "Welcome back"
        }
    }

    private var lastSevenMetrics: [HealthMetric] {
        Array(metrics.prefix(7)).sorted { $0.date < $1.date }
    }
}

    private struct MetricSummaryCard: View {
        let metric: HealthMetric

        private var distanceText: String {
            if let distance = metric.distance {
                let formatter = MeasurementFormatter()
                formatter.unitOptions = .providedUnit
                formatter.unitStyle = .short
                let measurement = Measurement(value: distance, unit: UnitLength.kilometers)
                return formatter.string(from: measurement)
            }
            return "—"
        }

        private var restingHeartRateText: String {
            if let value = metric.restingHeartRate {
                return "\(Int(value.rounded())) bpm"
            }
            return "—"
        }

        private var maxHeartRateText: String {
            if let value = metric.maxHeartRate {
                return "\(Int(value.rounded())) bpm"
            }
            return "—"
        }

        private var sleepText: String {
            guard let hours = metric.sleepHours else { return "—" }
            let efficiency = metric.sleepEfficiency.map { NumberFormatter.percent.string(from: NSNumber(value: $0)) }
            if let efficiency {
                return "\(hours.formatted(.number.precision(.fractionLength(1)))) h • \(efficiency)"
            }
            return "\(hours.formatted(.number.precision(.fractionLength(1)))) h"
        }

        private var vo2MaxText: String {
            if let value = metric.vo2Max {
                return "\(value.formatted(.number.precision(.fractionLength(1)))) ml/kg·min"
            }
            return "—"
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Label("Today", systemImage: "sun.max.fill")
                    .font(.headline)
            HStack(spacing: 16) {
                MetricPill(title: "Steps", value: "\(metric.stepCount.formatted())", systemImage: "figure.walk")
                MetricPill(title: "Energy", value: "\(metric.activeEnergy.formatted(.number.precision(.fractionLength(0)))) kcal", systemImage: "flame.fill")
            }
            HStack(spacing: 16) {
                MetricPill(title: "Active", value: "\(metric.activeMinutes) min", systemImage: "clock.badge")
                MetricPill(title: "Distance", value: distanceText, systemImage: "map")
            }
            HStack(spacing: 16) {
                MetricPill(title: "Resting HR", value: restingHeartRateText, systemImage: "heart")
                MetricPill(title: "Max HR", value: maxHeartRateText, systemImage: "waveform.path.ecg")
            }
            HStack(spacing: 16) {
                MetricPill(title: "Sleep", value: sleepText, systemImage: "bed.double.fill")
                MetricPill(title: "VO₂ Max", value: vo2MaxText, systemImage: "lungs.fill")
            }
            Text("Last updated \(metric.lastUpdatedAt, format: Date.FormatStyle(date: .omitted, time: .shortened))")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 6)
    }
}

private struct MetricPill: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.title3)
                .foregroundStyle(.accentColor)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground).opacity(0.9), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

private struct GoalProgressRow: View {
    @Bindable var goal: Goal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(goal.title, systemImage: goal.category.systemImageName)
                    .font(.subheadline.bold())
                Spacer()
                Text("\(goal.progressValue, format: .number.precision(.fractionLength(0))) / \(goal.targetValue, format: .number.precision(.fractionLength(0)))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: goal.completionRatio)
                .tint(.green)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        DashboardView()
            .environmentObject(HealthSyncViewModel())
    }
    .modelContainer(PreviewSampleData.makeContainer())
}
