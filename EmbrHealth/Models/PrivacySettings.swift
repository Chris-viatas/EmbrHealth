import Foundation
import SwiftData

@Model
final class PrivacySettings {
    var allowsWellnessAI: Bool
    var privacyNoticeAcceptedAt: Date?
    var gdprDeletionRequestedAt: Date?
    var ccpaDoNotSell: Bool
    var lastDataExportRequestedAt: Date?

    init(
        allowsWellnessAI: Bool = false,
        privacyNoticeAcceptedAt: Date? = nil,
        gdprDeletionRequestedAt: Date? = nil,
        ccpaDoNotSell: Bool = true,
        lastDataExportRequestedAt: Date? = nil
    ) {
        self.allowsWellnessAI = allowsWellnessAI
        self.privacyNoticeAcceptedAt = privacyNoticeAcceptedAt
        self.gdprDeletionRequestedAt = gdprDeletionRequestedAt
        self.ccpaDoNotSell = ccpaDoNotSell
        self.lastDataExportRequestedAt = lastDataExportRequestedAt
    }
}
