//
//  Item.swift
//  Spending Tracker
//
//  Created by Mahasvan on 31/05/26.
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
