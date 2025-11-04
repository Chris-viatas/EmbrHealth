import Foundation

enum WeightUnit: String, Codable, CaseIterable, Identifiable {
    case kilograms
    case pounds

    var id: Self { self }

    var displayName: String {
        switch self {
        case .kilograms:
            return "Kilograms"
        case .pounds:
            return "Pounds"
        }
    }

    var symbol: String {
        switch self {
        case .kilograms:
            return "kg"
        case .pounds:
            return "lbs"
        }
    }

    func fromBase(_ baseValue: Double) -> Double {
        switch self {
        case .kilograms:
            return baseValue
        case .pounds:
            return baseValue * 2.2046226218
        }
    }

    func toBase(_ value: Double) -> Double {
        switch self {
        case .kilograms:
            return value
        case .pounds:
            return value / 2.2046226218
        }
    }
}

enum HeightUnit: String, Codable, CaseIterable, Identifiable {
    case centimeters
    case imperial

    var id: Self { self }

    var displayName: String {
        switch self {
        case .centimeters:
            return "Centimeters"
        case .imperial:
            return "Feet & Inches"
        }
    }

    var symbol: String {
        switch self {
        case .centimeters:
            return "cm"
        case .imperial:
            return "ft/in"
        }
    }

    func fromBase(_ baseValue: Double) -> Double {
        switch self {
        case .centimeters:
            return baseValue
        case .imperial:
            return baseValue / 2.54
        }
    }

    func toBase(_ value: Double) -> Double {
        switch self {
        case .centimeters:
            return value
        case .imperial:
            return value * 2.54
        }
    }
}
