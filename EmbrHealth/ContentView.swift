import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var syncViewModel: HealthSyncViewModel

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label("Dashboard", systemImage: "house")
            }

            NavigationStack {
                GoalsView()
            }
            .tabItem {
                Label("Goals", systemImage: "target")
            }

            NavigationStack {
                TrendsView()
            }
            .tabItem {
                Label("Trends", systemImage: "chart.line.uptrend.xyaxis")
            }

            NavigationStack {
                CoachView()
            }
            .tabItem {
                Label("Coach", systemImage: "person.text.rectangle")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .environmentObject(syncViewModel)
    }
}

#Preview {
    ContentView()
        .environmentObject(HealthSyncViewModel(manager: HealthKitManager()))
        .modelContainer(PreviewSampleData.makeContainer())
}
