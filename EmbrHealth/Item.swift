//
//  Item.swift
//  EmbrHealth
//
//  Created by Christopher Hardin on 10/29/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
