//
//  Item.swift
//  Timers
//
//  Created by David McKenzie on 4/25/26.
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
