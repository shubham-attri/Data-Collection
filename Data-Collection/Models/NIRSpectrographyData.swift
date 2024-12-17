import Foundation
import iOS_BLE_Library

struct NIRSpectrographyData {
    let timestamp: UInt32
    let sensorValues: [UInt16] // 18 sensor channels
    
    init(data: Data) {
        var offset = 0
        
        // Extract timestamp (4 bytes)
        timestamp = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) }
        offset += 4
        
        // Extract sensor values (18 * 2 bytes)
        var values: [UInt16] = []
        for _ in 0..<18 {
            let value = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt16.self) }
            values.append(value)
            offset += 2
        }
        sensorValues = values
    }
} 