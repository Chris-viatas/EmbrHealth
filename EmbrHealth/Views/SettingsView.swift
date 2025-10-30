import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var syncViewModel: HealthSyncViewModel

    @Query(animation: .default)
    private var profiles: [UserProfile]

    @Query(animation: .default)
    private var privacySettings: [PrivacySettings]

    @State private var complianceMessage: String?

    var body: some View {
        Form {
            healthKitSection
            profileSection
            privacySection
            aboutSection
        }
        .navigationTitle("Settings")
        .task {
            ensureProfileExists()
            ensurePrivacySettingsExists()
        }
        .alert("Privacy Update", isPresented: Binding(get: { complianceMessage != nil }, set: { if !$0 { complianceMessage = nil } })) {
            Button("OK", role: .cancel) { complianceMessage = nil }
        } message: {
            if let complianceMessage { Text(complianceMessage) }
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

    private var privacySection: some View {
        Section("Privacy & Compliance") {
            if let settings = privacySettings.first {
                Toggle("Enable Wellness Coach (GPT-4.1)", isOn: Binding(
                    get: { settings.allowsWellnessAI },
                    set: { newValue in
                        settings.allowsWellnessAI = newValue
                        if newValue { settings.privacyNoticeAcceptedAt = .now }
                        saveContext()
                    }
                ))
                .toggleStyle(.switch)
                .accessibilityIdentifier("wellnessCoachToggle")

                Toggle("CCPA: Do not sell or share my data", isOn: Binding(
                    get: { settings.ccpaDoNotSell },
                    set: { newValue in
                        settings.ccpaDoNotSell = newValue
                        saveContext()
                    }
                ))

                Button("Request Data Export") {
                    settings.lastDataExportRequestedAt = .now
                    saveContext()
                    complianceMessage = "We have recorded your GDPR/CCPA export request. You will receive a confirmation once the export is ready."
                }

                Button("Request Data Deletion (GDPR)", role: .destructive) {
                    settings.gdprDeletionRequestedAt = .now
                    saveContext()
                    complianceMessage = "Your deletion request has been logged. We'll guide you through removing all local data and disabling integrations."
                }

                if let exportDate = settings.lastDataExportRequestedAt {
                    Text("Last export request: \(exportDate, style: .date)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let deletionDate = settings.gdprDeletionRequestedAt {
                    Text("Deletion requested: \(deletionDate, style: .date)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Personal data (PII) remains in your profile record and never leaves the device. Health metrics are stored separately and only aggregated insights are shared with the AI when enabled.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else {
                ProgressView()
            }
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

    private func ensurePrivacySettingsExists() {
        guard privacySettings.isEmpty else { return }
        let settings = PrivacySettings()
        context.insert(settings)
        try? context.save()
    }

    private func saveContext() {
        do {
            try context.save()
        } catch {
            complianceMessage = "Unable to persist your privacy preferences: \(error.localizedDescription)"
        }
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
