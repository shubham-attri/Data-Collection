import Foundation

struct NIRSpectrographyData {
    let timestamp: UInt32
    let sensorValues: [UInt16]  // 18 sensor channels
    
    static let serviceUUID = CBUUID(string: "1819")
    static let characteristicUUID = CBUUID(string: "2A3E")
    
    init(data: Data) throws {
        guard data.count >= 4 + (18 * 2) else {
            throw BLEError.invalidDataFormat
        }
        
        // Extract timestamp (first 4 bytes)
        timestamp = data.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self) }
        
        // Extract sensor values (18 UInt16 values)
        var values: [UInt16] = []
        for i in 0..<18 {
            let startIndex = 4 + (i * 2)
            let value = data.subdata(in: startIndex..<(startIndex + 2)).withUnsafeBytes { $0.load(as: UInt16.self) }
            values.append(value)
        }
        sensorValues = values
    }
} 