import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var syncViewModel: HealthSyncViewModel

    @Query(animation: .default)
    private var profiles: [UserProfile]

    var body: some View {
        Form {
            healthKitSection
            profileSection
            aboutSection
        }
        .navigationTitle("Settings")
        .task {
            ensureProfileExists()
        }
    }

    private var healthKitSection: some View {
        Section("Health Data") {
            HStack {
                Label("Authorization", systemImage: "heart.circle")
                Spacer()
                Text(statusText)
                    .foregroundStyle(statusColor)
            }
            Button {
                Task { await syncViewModel.requestAuthorization() }
            } label: {
                Label("Request Access", systemImage: "hand.raised")
            }
            .disabled(syncViewModel.authorizationState == .unavailable)

            if let lastSyncDate = syncViewModel.lastSyncDate {
                Label("Last synced \(lastSyncDate, style: .relative) ago", systemImage: "clock")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let error = syncViewModel.lastSyncError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var profileSection: some View {
        Section("Profile") {
            if let profile = profiles.first {
                ProfileForm(profile: profile)
            } else {
                ProgressView()
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: Bundle.main.appVersion)
            LabeledContent("Build", value: Bundle.main.appBuild)
            Link("Learn about Health permissions", destination: URL(string: "https://support.apple.com/en-us/HT204351")!)
        }
    }

    private var statusText: String {
        switch syncViewModel.authorizationState {
        case .unknown:
            return "Unknown"
        case .authorized:
            return "Granted"
        case .denied:
            return "Denied"
        case .unavailable:
            return "Unavailable"
        }
    }

    private var statusColor: Color {
        switch syncViewModel.authorizationState {
        case .authorized:
            return .green
        case .denied:
            return .red
        case .unknown:
            return .secondary
        case .unavailable:
            return .gray
        }
    }

    private func ensureProfileExists() {
        guard profiles.isEmpty else { return }
        let profile = UserProfile(givenName: "", primaryGoal: .steps)
        context.insert(profile)
        try? context.save()
    }
}

private struct ProfileForm: View {
    @Bindable var profile: UserProfile

    var body: some View {
        TextField("Name", text: $profile.givenName)
        Picker("Primary Goal", selection: $profile.primaryGoal) {
            ForEach(GoalCategory.allCases) { category in
                Text(category.name).tag(category)
            }
        }
        Toggle("Notifications", isOn: $profile.prefersNotifications)
        Stepper(value: Binding(get: { profile.age ?? 25 }, set: { profile.age = $0 }), in: 13...100) {
            Text("Age: \((profile.age ?? 25).formatted())")
        }
        Stepper(value: Binding(get: { profile.height ?? 170 }, set: { profile.height = $0 }), in: 100...220, step: 1) {
            Text("Height: \((profile.height ?? 170).formatted()) cm")
        }
        Stepper(value: Binding(get: { profile.weight ?? 70 }, set: { profile.weight = $0 }), in: 40...200, step: 1) {
            Text("Weight: \((profile.weight ?? 70).formatted()) kg")
        }
    }
}

private extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var appBuild: String {
        infoDictionary?[kCFBundleVersionKey as String] as? String ?? "—"
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(HealthSyncViewModel())
    }
    .modelContainer(PreviewSampleData.makeContainer())
}
