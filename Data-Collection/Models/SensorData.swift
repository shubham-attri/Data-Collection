import Foundation
import SwiftData

@Model
class SensorData {
    var timestamp: Date
    var value: Double
    var deviceId: String
    var isSynced: Bool
    
    init(timestamp: Date, value: Double, deviceId: String, isSynced: Bool = false) {
        self.timestamp = timestamp
        self.value = value
        self.deviceId = deviceId
        self.isSynced = isSynced
    }
} 