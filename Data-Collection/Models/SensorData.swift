import Foundation
import SwiftData

@Model
final class SensorData {
    var timestamp: Date
    var value: Double
    var deviceId: String
    var isSynced: Bool
    var channelIndex: Int
    
    init(timestamp: Date, value: Double, deviceId: String, channelIndex: Int, isSynced: Bool = false) {
        self.timestamp = timestamp
        self.value = value
        self.deviceId = deviceId
        self.channelIndex = channelIndex
        self.isSynced = isSynced
    }
} 