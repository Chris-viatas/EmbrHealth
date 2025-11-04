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
        Picker("Height Units", selection: $profile.preferredHeightUnit) {
            ForEach(HeightUnit.allCases) { unit in
                Text(unit.displayName).tag(unit)
            }
        }
        .pickerStyle(.segmented)

        switch profile.preferredHeightUnit {
        case .centimeters:
            Stepper(value: heightMetricBinding, in: 100...220, step: 1) {
                let heightCentimeters = heightMetricBinding.wrappedValue
                let components = heightComponents(from: heightCentimeters)
                Text("Height: \(formattedNumber(heightCentimeters)) cm (\(components.feet) ft \(components.inches) in)")
            }
        case .imperial:
            Stepper(value: heightFeetBinding, in: 3...8, step: 1) {
                Text("Feet: \(heightFeetBinding.wrappedValue) ft")
            }
            Stepper(value: heightInchesBinding, in: 0...11, step: 1) {
                Text("Inches: \(heightInchesBinding.wrappedValue) in")
            }
            Text(imperialHeightSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Picker("Weight Units", selection: $profile.preferredWeightUnit) {
            ForEach(WeightUnit.allCases) { unit in
                Text(unit.displayName).tag(unit)
            }
        }
        .pickerStyle(.segmented)

        Stepper(value: weightBinding, in: weightRange, step: weightStep) {
            Text(weightSummary)
        }
    }
}

private extension ProfileForm {
    var defaultHeightCentimeters: Double { 170 }
    var defaultWeightKilograms: Double { 70 }

    var heightMetricBinding: Binding<Double> {
        Binding(
            get: { profile.height ?? defaultHeightCentimeters },
            set: { profile.height = $0 }
        )
    }

    var heightFeetBinding: Binding<Int> {
        Binding(
            get: {
                let components = heightComponents(from: profile.height ?? defaultHeightCentimeters)
                return components.feet
            },
            set: { newFeet in
                let current = heightComponents(from: profile.height ?? defaultHeightCentimeters)
                profile.height = centimeters(fromFeet: newFeet, inches: current.inches)
            }
        )
    }

    var heightInchesBinding: Binding<Int> {
        Binding(
            get: {
                let components = heightComponents(from: profile.height ?? defaultHeightCentimeters)
                return components.inches
            },
            set: { newInches in
                let current = heightComponents(from: profile.height ?? defaultHeightCentimeters)
                let clamped = min(max(newInches, 0), 11)
                profile.height = centimeters(fromFeet: current.feet, inches: clamped)
            }
        )
    }

    var weightBinding: Binding<Double> {
        Binding(
            get: {
                let kilograms = profile.weight ?? defaultWeightKilograms
                return profile.preferredWeightUnit.fromBase(kilograms)
            },
            set: { newValue in
                profile.weight = profile.preferredWeightUnit.toBase(newValue)
            }
        )
    }

    var weightRange: ClosedRange<Double> {
        switch profile.preferredWeightUnit {
        case .kilograms:
            return 40...200
        case .pounds:
            let lower = WeightUnit.pounds.fromBase(40)
            let upper = WeightUnit.pounds.fromBase(200)
            return lower...upper
        }
    }

    var weightStep: Double {
        switch profile.preferredWeightUnit {
        case .kilograms:
            return 1
        case .pounds:
            return 1
        }
    }

    var weightSummary: String {
        let kilograms = profile.weight ?? defaultWeightKilograms
        let pounds = WeightUnit.pounds.fromBase(kilograms)
        switch profile.preferredWeightUnit {
        case .kilograms:
            return "Weight: \(formattedNumber(kilograms)) kg (\(formattedNumber(pounds)) lbs)"
        case .pounds:
            return "Weight: \(formattedNumber(pounds)) lbs (\(formattedNumber(kilograms)) kg)"
        }
    }

    var imperialHeightSummary: String {
        let centimeters = profile.height ?? defaultHeightCentimeters
        let components = heightComponents(from: centimeters)
        return "Height: \(components.feet) ft \(components.inches) in (\(formattedNumber(centimeters)) cm)"
    }

    func heightComponents(from centimeters: Double) -> (feet: Int, inches: Int) {
        let totalInches = centimeters / 2.54
        var feet = Int(totalInches / 12)
        let remainingInches = totalInches - Double(feet * 12)
        var inches = Int(round(remainingInches))
        if inches == 12 {
            feet += 1
            inches = 0
        }
        return (feet, inches)
    }

    func centimeters(fromFeet feet: Int, inches: Int) -> Double {
        let totalInches = Double(feet * 12 + inches)
        return totalInches * 2.54
    }

    func formattedNumber(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
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
            .environmentObject(HealthSyncViewModel(manager: HealthKitManager()))
    }
    .modelContainer(PreviewSampleData.makeContainer())
}
