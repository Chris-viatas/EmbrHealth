import Foundation
import SwiftData

@MainActor
final class HealthSyncViewModel: ObservableObject {
    enum AuthorizationState {
        case unknown
        case authorized
        case denied
        case unavailable
    }

    @Published private(set) var authorizationState: AuthorizationState = .unknown
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var isSyncing = false
    @Published var lastSyncError: String?

    private let manager: HealthKitManager

    init(manager: HealthKitManager = HealthKitManager()) {
        self.manager = manager
        authorizationState = manager.isHealthDataAvailable() ? .unknown : .unavailable
    }

    func requestAuthorization() async {
        guard authorizationState != .unavailable else { return }
        do {
            let granted = try await manager.requestAuthorization()
            authorizationState = granted ? .authorized : .denied
            if granted {
                manager.enableBackgroundDelivery()
            }
        } catch {
            authorizationState = .denied
            lastSyncError = error.localizedDescription
        }
    }

    func syncTodayIfNeeded(with context: ModelContext) async {
        guard authorizationState == .authorized else { return }
        let now = Date()
        if let lastSyncDate, Calendar.current.isDate(lastSyncDate, inSameDayAs: now) { return }
        await sync(for: now, context: context)
    }

    func sync(for date: Date, context: ModelContext) async {
        guard authorizationState == .authorized else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            let summary = try await manager.fetchDailySummary(for: date)
            try upsertMetric(summary: summary, on: date, context: context)
            lastSyncDate = Date()
            lastSyncError = nil
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    private func upsertMetric(summary: DailyActivitySummary, on date: Date, context: ModelContext) throws {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }
        let predicate = #Predicate<HealthMetric> { metric in
            metric.date >= startOfDay && metric.date < endOfDay
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            existing.stepCount = summary.steps
            existing.activeEnergy = summary.activeEnergy
            existing.activeMinutes = summary.exerciseMinutes
            existing.distance = summary.distance
            existing.lastUpdatedAt = .now
        } else {
            let metric = HealthMetric(
                date: startOfDay,
                stepCount: summary.steps,
                activeEnergy: summary.activeEnergy,
                activeMinutes: summary.exerciseMinutes,
                distance: summary.distance,
                lastUpdatedAt: .now
            )
            context.insert(metric)
        }
        try context.save()
    }
}
