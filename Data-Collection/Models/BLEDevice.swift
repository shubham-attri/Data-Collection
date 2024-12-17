import Foundation
import CoreBluetooth

struct BLEDevice: Identifiable {
    let peripheral: CBPeripheral
    var id: UUID { peripheral.identifier }
    var name: String { peripheral.name ?? "Unknown Device" }
} 