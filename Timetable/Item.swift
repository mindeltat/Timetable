//
//  Item.swift
//  Timetable
//
//  Created by Zack on 2026/9/29.
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
