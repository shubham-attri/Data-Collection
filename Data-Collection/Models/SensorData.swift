import Foundation
import SwiftData

@Model
final class SensorData {
    var id: UUID
    var timestamp: Date
    var value: Double
    var deviceId: String
    var isSynced: Bool
    
    init(id: UUID = UUID(), timestamp: Date = Date(), value: Double, deviceId: String, isSynced: Bool = false) {
        self.id = id
        self.timestamp = timestamp
        self.value = value
        self.deviceId = deviceId
        self.isSynced = isSynced
    }
} 