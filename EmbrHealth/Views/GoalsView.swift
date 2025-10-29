import SwiftData
import SwiftUI

struct GoalsView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Goal> { !$0.isArchived }, sort: \Goal.createdAt, order: .reverse, animation: .easeInOut)
    private var goals: [Goal]

    @State private var showingAddGoal = false
    @State private var selection: Goal?

    var body: some View {
        List(selection: $selection) {
            if goals.isEmpty {
                ContentUnavailableView(
                    "No goals yet",
                    systemImage: "target",
                    description: Text("Tap the plus button to create your first goal.")
                )
            } else {
                ForEach(goals) { goal in
                    GoalRow(goal: goal)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                archive(goal: goal)
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                        }
                }
            }
        }
        .navigationTitle("Goals")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddGoal.toggle()
                } label: {
                    Label("Add Goal", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddGoal) {
            AddGoalSheet { newGoal in
                context.insert(newGoal)
                try? context.save()
            }
            .presentationDetents([.medium])
        }
    }

    private func archive(goal: Goal) {
        goal.isArchived = true
        try? context.save()
    }
}

private struct GoalRow: View {
    @Bindable var goal: Goal

    private var remainingText: String {
        if let deadline = goal.deadline {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return formatter.localizedString(for: deadline, relativeTo: .now)
        }
        return "Flexible deadline"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(goal.title, systemImage: goal.category.systemImageName)
                    .font(.headline)
                Spacer()
                Text(goal.category.unitDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: goal.completionRatio)
                .tint(goal.completionRatio >= 1 ? .green : .blue)
            HStack {
                Text("Progress: \(goal.progressValue, format: .number.precision(.fractionLength(0))) / \(goal.targetValue, format: .number.precision(.fractionLength(0)))")
                Spacer()
                Text(remainingText)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .padding(.vertical, 8)
    }
}

private struct AddGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var category: GoalCategory = .steps
    @State private var target: Double = GoalCategory.steps.defaultTarget
    @State private var deadline: Date = .now
    @State private var hasDeadline = false

    var onSave: (Goal) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Goal title", text: $title)
                    Picker("Category", selection: $category) {
                        ForEach(GoalCategory.allCases) { category in
                            Label(category.name, systemImage: category.systemImageName)
                                .tag(category)
                        }
                    }
                    Stepper(value: $target, in: 1...100_000, step: stepValue(for: category)) {
                        Text("Target: \(target.formatted(.number.precision(.fractionLength(0)))) \(category.unitDescription)")
                    }
                }

                Section("Deadline") {
                    Toggle("Set deadline", isOn: $hasDeadline.animation())
                    if hasDeadline {
                        DatePicker("Complete by", selection: $deadline, displayedComponents: [.date])
                    }
                }
            }
            .navigationTitle("New Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let newGoal = Goal(
                            title: title.isEmpty ? defaultTitle(for: category) : title,
                            category: category,
                            targetValue: target,
                            deadline: hasDeadline ? deadline : nil
                        )
                        onSave(newGoal)
                        dismiss()
                    }
                }
            }
            .onChange(of: category) { newCategory in
                if title.isEmpty {
                    title = defaultTitle(for: newCategory)
                }
                target = newCategory.defaultTarget
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func stepValue(for category: GoalCategory) -> Double {
        switch category {
        case .steps:
            return 500
        case .calories:
            return 25
        case .workouts:
            return 1
        case .sleep:
            return 0.5
        }
    }

    private func defaultTitle(for category: GoalCategory) -> String {
        "\(category.name) Goal"
    }
}

#Preview {
    NavigationStack {
        GoalsView()
    }
    .modelContainer(PreviewSampleData.makeContainer())
}
