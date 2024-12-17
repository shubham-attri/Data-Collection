import Foundation
import SwiftData
import CoreBluetooth
import Combine
import os.log

class BluetoothManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isScanning = false
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var connectedDevice: CBPeripheral?
    @Published var connectionState: ConnectionState = .disconnected
    @Published var errorMessage: String?
    @Published var batteryLevel: UInt8 = 0
    @Published var nirData: NIRSpectrographyData?
    
    // MARK: - Private Properties
    private var centralManager: CBCentralManager?
    private var modelContext: ModelContext?
    private let logger = Logger(subsystem: "com.example.datacollection", category: "BluetoothManager")
    
    // MARK: - Service UUIDs
    private let batteryServiceUUID = CBUUID(string: "180F")
    private let writeServiceUUID = CBUUID(string: "1818")
    private let readServiceUUID = CBUUID(string: "1819")
    
    // MARK: - Characteristic UUIDs
    private let batteryCharUUID = CBUUID(string: "2A19")
    private let writeCharUUID = CBUUID(string: "2A3D")
    private let notifyCharUUID = CBUUID(string: "2A3E")
    
    // MARK: - Types
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case failed(Error)
    }
    
    // MARK: - Initialization
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        logger.info("BluetoothManager initialized")
    }
    
    // MARK: - Public Methods
    func startScanning() {
        guard centralManager?.state == .poweredOn else {
            errorMessage = "Bluetooth is not available"
            return
        }
        
        let services = [batteryServiceUUID, writeServiceUUID, readServiceUUID]
        centralManager?.scanForPeripherals(withServices: services, options: nil)
        isScanning = true
        logger.info("Started scanning for devices")
    }
    
    func stopScanning() {
        centralManager?.stopScan()
        isScanning = false
        logger.info("Stopped scanning")
    }
    
    func connect(to peripheral: CBPeripheral) {
        logger.info("Attempting to connect to peripheral: \(peripheral.identifier)")
        connectionState = .connecting
        centralManager?.connect(peripheral, options: nil)
    }
    
    // MARK: - Command Methods
    func sendCommand(_ command: [UInt8], characteristic: CBUUID) {
        guard let peripheral = connectedDevice else {
            errorMessage = "No device connected"
            return
        }
        
        guard let service = peripheral.services?.first(where: { $0.uuid == writeServiceUUID }),
              let characteristic = service.characteristics?.first(where: { $0.uuid == characteristic }) else {
            errorMessage = "Required characteristic not found"
            return
        }
        
        peripheral.writeValue(Data(command), for: characteristic, type: .withResponse)
        logger.info("Sent command: \(command) to characteristic: \(characteristic.uuid)")
    }
    
    func checkMemoryStatus() {
        let command: [UInt8] = [0x01] // Check memory command
        sendCommand(command, characteristic: writeCharUUID)
    }
    
    func requestStoredData() {
        let command: [UInt8] = [0x02] // Request data command
        sendCommand(command, characteristic: writeCharUUID)
    }
    
    func startDataCollection() {
        // Create command: 0x03 followed by current timestamp
        var command: [UInt8] = [0x03]
        let timestamp = UInt32(Date().timeIntervalSince1970 * 1000) // milliseconds
        command.append(contentsOf: withUnsafeBytes(of: timestamp) { Array($0) })
        
        sendCommand(command, characteristic: writeCharUUID)
    }
    
    func stopDataCollection() {
        let command: [UInt8] = [0x04] // Stop and clear command
        sendCommand(command, characteristic: writeCharUUID)
    }
    
    private func saveReading(_ nirData: NIRSpectrographyData?) {
        guard let nirData = nirData,
              let deviceId = connectedDevice?.identifier.uuidString,
              let modelContext = modelContext else { return }
        
        // Create a SensorData object for each sensor value
        for (index, value) in nirData.sensorValues.enumerated() {
            let reading = SensorData(
                timestamp: Date(timeIntervalSince1970: TimeInterval(nirData.timestamp) / 1000.0),
                value: Double(value),
                deviceId: "\(deviceId)-sensor\(index)",
                isSynced: false
            )
            modelContext.insert(reading)
        }
        
        do {
            try modelContext.save()
            logger.info("Saved sensor readings to database")
        } catch {
            logger.error("Failed to save readings: \(error.localizedDescription)")
            errorMessage = "Failed to save readings: \(error.localizedDescription)"
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            logger.info("Bluetooth is powered on")
            startScanning()
        case .poweredOff:
            logger.error("Bluetooth is powered off")
            errorMessage = "Bluetooth is turned off"
        case .unauthorized:
            logger.error("Bluetooth is unauthorized")
            errorMessage = "Bluetooth permission denied"
        default:
            logger.error("Bluetooth is unavailable: \(central.state.rawValue)")
            errorMessage = "Bluetooth is not available"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if !discoveredDevices.contains(peripheral) {
            logger.info("Discovered peripheral: \(peripheral.identifier)")
            discoveredDevices.append(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.info("Connected to peripheral: \(peripheral.identifier)")
        connectedDevice = peripheral
        connectionState = .connected
        peripheral.delegate = self
        peripheral.discoverServices([batteryServiceUUID, writeServiceUUID, readServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        logger.error("Failed to connect: \(error?.localizedDescription ?? "unknown error")")
        connectionState = .failed(error ?? NSError(domain: "com.example.datacollection", code: -1, userInfo: nil))
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            logger.error("Service discovery failed: \(error.localizedDescription)")
            errorMessage = "Service discovery failed: \(error.localizedDescription)"
            return
        }
        
        peripheral.services?.forEach { service in
            switch service.uuid {
            case batteryServiceUUID:
                peripheral.discoverCharacteristics([batteryCharUUID], for: service)
            case writeServiceUUID:
                peripheral.discoverCharacteristics([writeCharUUID], for: service)
            case readServiceUUID:
                peripheral.discoverCharacteristics([notifyCharUUID], for: service)
            default:
                break
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            logger.error("Characteristic discovery failed: \(error.localizedDescription)")
            errorMessage = "Characteristic discovery failed: \(error.localizedDescription)"
            return
        }
        
        service.characteristics?.forEach { characteristic in
            switch characteristic.uuid {
            case notifyCharUUID:
                peripheral.setNotifyValue(true, for: characteristic)
            case batteryCharUUID:
                peripheral.readValue(for: characteristic)
            default:
                break
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            logger.error("Value update failed: \(error.localizedDescription)")
            errorMessage = "Value update failed: \(error.localizedDescription)"
            return
        }
        
        guard let data = characteristic.value else { return }
        
        switch characteristic.uuid {
        case batteryCharUUID:
            if let value = data.first {
                batteryLevel = value
                logger.info("Updated battery level: \(value)%")
            }
        case notifyCharUUID:
            nirData = NIRSpectrographyData(data: data)
            logger.info("Received NIR data")
            saveReading(nirData)
        default:
            break
        }
    }
}
