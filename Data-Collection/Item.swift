//
//  Item.swift
//  Data-Collection
//
//  Created by Shubham Attri on 16/12/24.
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
