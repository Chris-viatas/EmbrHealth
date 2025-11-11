import SwiftUI

struct SymptomSelector: View {
    let symptoms: [Symptom]
    @Binding var selectedSymptoms: Set<Symptom>
    let isProcessing: Bool
    let onSubmit: () -> Void

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 140), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("How are you feeling today?")
                    .font(.headline)
                Text("Tap any symptoms you're experiencing and send them to your coach for quick guidance.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(symptoms) { symptom in
                    SymptomTile(
                        symptom: symptom,
                        isSelected: selectedSymptoms.contains(symptom)
                    ) {
                        toggle(symptom)
                    }
                }
            }

            Button(action: onSubmit) {
                Label("Send to Coach", systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedSymptoms.isEmpty || isProcessing)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func toggle(_ symptom: Symptom) {
        if selectedSymptoms.contains(symptom) {
            selectedSymptoms.remove(symptom)
        } else {
            selectedSymptoms.insert(symptom)
        }
    }
}

private struct SymptomTile: View {
    let symptom: Symptom
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(symptom.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .white : .primary)
        .background(background)
        .overlay(border)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    private var background: some View {
        Group {
            if isSelected {
                Color.accentColor
            } else {
                Color(.secondarySystemBackground)
            }
        }
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(Color.accentColor.opacity(isSelected ? 0 : 0.6), lineWidth: 1)
    }
}

#Preview {
    SymptomSelector(
        symptoms: Symptom.allCases,
        selectedSymptoms: .constant([.cough, .fever]),
        isProcessing: false,
        onSubmit: {}
    )
    .padding()
    .previewLayout(.sizeThatFits)
}
