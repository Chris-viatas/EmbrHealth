import Foundation

enum HealthConversationGuard {
    private static let disallowedKeywords: [String] = [
        "password",
        "social security",
        "ssn",
        "credit card",
        "bank account",
        "routing number",
        "passport"
    ]

    static func allows(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return !disallowedKeywords.contains(where: { lowercased.contains($0) })
    }

    static func scrub(_ text: String) -> String {
        var sanitized = text
        let patterns: [String] = [
            #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}"#,
            #"\\b[0-9]{3}[-. ]?[0-9]{2}[-. ]?[0-9]{4}\\b"#,
            #"\\b[0-9]{10,}\\b"#
        ]
        patterns.forEach { pattern in
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(location: 0, length: (sanitized as NSString).length)
                sanitized = regex.stringByReplacingMatches(in: sanitized, options: [], range: range, withTemplate: "[redacted]")
            }
        }
        return sanitized
    }
}
