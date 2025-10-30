import Foundation

struct WellnessChatMessage: Identifiable, Hashable {
    enum Sender {
        case user
        case coach
    }

    let id: UUID
    let sender: Sender
    let text: String
    let timestamp: Date

    init(id: UUID = UUID(), sender: Sender, text: String, timestamp: Date = .now) {
        self.id = id
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
    }
}
