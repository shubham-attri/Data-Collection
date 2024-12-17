import Foundation
import iOS_BLE_Library

struct BLEDevice: Identifiable {
    let peripheral: Peripheral
    var id: UUID { peripheral.identifier }
    var name: String { peripheral.name ?? "Unknown Device" }
} 