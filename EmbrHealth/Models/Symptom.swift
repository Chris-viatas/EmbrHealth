import Foundation

enum Symptom: String, CaseIterable, Identifiable {
    case cough
    case fever
    case chills
    case vomiting
    case upsetStomach
    case runnyNose
    case soreThroat
    case headache
    case kneePain
    case shoulderPain
    case chestPain
    case chestCongestion

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cough: "Cough"
        case .fever: "Fever"
        case .chills: "Chills"
        case .vomiting: "Throwing Up"
        case .upsetStomach: "Upset Stomach"
        case .runnyNose: "Runny Nose"
        case .soreThroat: "Sore Throat"
        case .headache: "Headache"
        case .kneePain: "Knee Pain"
        case .shoulderPain: "Shoulder Pain"
        case .chestPain: "Chest Pain"
        case .chestCongestion: "Chest Congestion"
        }
    }

    var promptDescription: String {
        switch self {
        case .vomiting:
            return "throwing up"
        case .upsetStomach:
            return "an upset stomach"
        case .runnyNose:
            return "a runny nose"
        case .soreThroat:
            return "a sore throat"
        case .kneePain:
            return "knee pain"
        case .shoulderPain:
            return "shoulder pain"
        case .chestPain:
            return "chest pain"
        case .chestCongestion:
            return "chest congestion"
        default:
            return title.lowercased()
        }
    }
}
