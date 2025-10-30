import SwiftUI
import SwiftData

@main
struct EmbrHealthApp: App {
    @StateObject private var healthSyncViewModel = HealthSyncViewModel(manager: HealthKitManager())

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            HealthMetric.self,
            Goal.self,
            Workout.self,
            UserProfile.self,
            PrivacySettings.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthSyncViewModel)
        }
        .modelContainer(sharedModelContainer)
    }
}
