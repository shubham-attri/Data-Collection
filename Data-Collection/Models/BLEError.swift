import Foundation

enum BLEError: LocalizedError {
    case invalidDataFormat
    case deviceNotFound
    case serviceNotFound
    case characteristicNotFound
    case notConnected
    case writeFailed
    case invalidState
    
    var errorDescription: String? {
        switch self {
        case .invalidDataFormat:
            return "Invalid data format received"
        case .deviceNotFound:
            return "BLE device not found"
        case .serviceNotFound:
            return "Required BLE service not found"
        case .characteristicNotFound:
            return "Required BLE characteristic not found"
        case .notConnected:
            return "Device not connected"
        case .writeFailed:
            return "Failed to write to device"
        case .invalidState:
            return "Invalid BLE state"
        }
    }
} 