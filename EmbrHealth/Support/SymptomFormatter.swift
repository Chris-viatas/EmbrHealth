import Foundation

struct SymptomFormatter {
    static func summary(for symptoms: Set<Symptom>) -> String {
        let formatter = ListFormatter()
        formatter.locale = .current
        let descriptions = symptoms
            .sorted { $0.title < $1.title }
            .map { $0.promptDescription }
        let list = formatter.string(from: descriptions) ?? descriptions.joined(separator: ", ")
        return "I am experiencing \(list)."
    }
}
