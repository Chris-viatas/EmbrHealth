import SwiftData
import SwiftUI

struct CoachView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var syncViewModel: HealthSyncViewModel
    @StateObject private var viewModel = WellnessCoachViewModel()

    @Query(sort: \HealthMetric.date, order: .reverse, animation: .default)
    private var metrics: [HealthMetric]

    @Query(filter: #Predicate<Goal> { !$0.isArchived }, sort: \Goal.createdAt, order: .forward, animation: .default)
    private var goals: [Goal]

    @Query(sort: \Workout.date, order: .reverse, animation: .default)
    private var workouts: [Workout]

    @Query
    private var privacySettings: [PrivacySettings]

    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        Group {
            if let settings = privacySettings.first {
                if settings.allowsWellnessAI {
                    conversationView
                } else {
                    ContentUnavailableView(
                        "Coach disabled",
                        systemImage: "lock.shield",
                        description: Text("Enable the wellness coach from Settings → Privacy & Compliance to chat about your trends.")
                    )
                    .padding()
                }
            } else {
                ProgressView("Preparing privacy controls…")
            }
        }
        .navigationTitle("Coach")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if allowsCoachAccess {
                    Button {
                        Task { await syncViewModel.sync(for: Date(), context: context) }
                    } label: {
                        Label("Sync", systemImage: "arrow.clockwise")
                    }
                    .disabled(syncViewModel.isSyncing)
                }
            }
        }
        .alert("Coach Error", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            if let errorMessage = viewModel.errorMessage { Text(errorMessage) }
        }
        .task {
            ensurePrivacySettingsExist()
            viewModel.bootstrap()
        }
    }

    private var conversationView: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                        if viewModel.isProcessing {
                            ProgressView("Thinking…")
                                .font(.caption)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages) { _ in
                    if let last = viewModel.messages.last {
                        withAnimation(.easeInOut) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            Divider()
            HStack(alignment: .bottom) {
                TextField("Ask about your wellness…", text: $messageText, axis: .vertical)
                    .focused($isInputFocused)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { sendMessage() }
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.title3)
                }
                .disabled(viewModel.isProcessing || messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }

    private var allowsCoachAccess: Bool {
        privacySettings.first?.allowsWellnessAI == true
    }

    private func sendMessage() {
        let text = messageText
        messageText = ""
        isInputFocused = false
        Task {
            await viewModel.send(text, metrics: metrics, goals: goals, workouts: workouts)
        }
    }

    private func ensurePrivacySettingsExist() {
        guard privacySettings.isEmpty else { return }
        let settings = PrivacySettings()
        context.insert(settings)
        try? context.save()
    }
}

private struct ChatBubble: View {
    let message: WellnessChatMessage

    var body: some View {
        HStack {
            if message.sender == .coach {
                bubble
                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)
                bubble
            }
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.text)
                .font(.body)
            Text(message.timestamp, style: .time)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(message.sender == .coach ? Color(.secondarySystemBackground) : Color.accentColor.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        CoachView()
    }

    .environmentObject(HealthSyncViewModel(manager: HealthKitManager()))

    .environmentObject(HealthSyncViewModel())

    .modelContainer(PreviewSampleData.makeContainer())
}
