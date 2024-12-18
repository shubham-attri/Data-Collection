import Foundation
import SwiftData
import CoreBluetooth
import Combine
import os.log

enum ConnectionState {
    case disconnected
    case connecting
    case connected
}

// Protocol to abstract peripheral behavior
protocol Peripheral: AnyObject {
    var name: String? { get }
    var identifier: UUID { get }
}

extension CBPeripheral: Peripheral {}

class BluetoothManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var connectionState: ConnectionState = .disconnected
    @Published var isScanning = false
    @Published var batteryLevel: UInt8 = 0
    @Published var errorMessage: String?
    
    @Published var isCollectingData = false
    @Published var isSyncing = false
    
    // Add modelContext as a property
    private let modelContext: ModelContext
    
    #if targetEnvironment(simulator)
    @Published var discoveredDevices: [MockPeripheral] = []
    var connectedPeripheral: MockPeripheral?
    private var mockTimer: Timer?
    
    // Add mock characteristic for simulator
    private var mockWriteCharacteristic: MockCharacteristic?
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        super.init()
        // Simulate initial delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.simulateDeviceDiscovery()
        }
    }
    
    private func simulateDeviceDiscovery() {
        let mockDevice = MockPeripheral(name: "GT TURBO")
        if !discoveredDevices.contains(where: { $0.identifier == mockDevice.identifier }) {
            discoveredDevices = [mockDevice]
        }
    }
    
    #else
    // MARK: - Real Device Properties
    @Published var discoveredDevices: [CBPeripheral] = []
    var connectedPeripheral: CBPeripheral?
    private var centralManager: CBCentralManager!
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    
    private let serviceUUIDs = [
        CBUUID(string: "180F"), // Battery
        CBUUID(string: "1818"), // Write
        CBUUID(string: "1819")  // Read
    ]
    
    private let characteristicUUIDs = [
        CBUUID(string: "2A19"), // Battery
        CBUUID(string: "2A3D"), // Write (Control)
        CBUUID(string: "2A3E")  // Read (Data)
    ]
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    #endif
    
    // MARK: - Common Public Methods
    func startScanning() {
        isScanning = true
        #if targetEnvironment(simulator)
        simulateDeviceDiscovery()
        #else
        guard let central = centralManager,
              central.state == .poweredOn else {
            errorMessage = "Bluetooth not ready"
            return
        }
        central.scanForPeripherals(withServices: serviceUUIDs)
        #endif
    }
    
    func stopScanning() {
        isScanning = false
        #if !targetEnvironment(simulator)
        centralManager?.stopScan()
        #endif
    }
    
    func connect(to peripheral: Peripheral) {
        connectionState = .connecting
        #if targetEnvironment(simulator)
        // Simulate connection delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.connectionState = .connected
            self.connectedPeripheral = peripheral as? MockPeripheral
            self.stopScanning()  // Stop scanning after connection
        }
        #else
        guard let cbPeripheral = peripheral as? CBPeripheral else { return }
        centralManager?.connect(cbPeripheral)
        stopScanning()  // Stop scanning after initiating connection
        #endif
    }
    
    func startDataCollection() {
        #if targetEnvironment(simulator)
        isCollectingData = true
        mockTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.simulateNewReading()
        }
        #else
        guard let peripheral = connectedPeripheral,
              let characteristic = writeCharacteristic else { 
            errorMessage = "Device not ready"
            return 
        }
        
        isCollectingData = true
        let command: [UInt8] = [1]
        peripheral.writeValue(Data(command), for: characteristic, type: .withResponse)
        #endif
    }
    
    func stopDataCollection() {
        #if targetEnvironment(simulator)
        mockTimer?.invalidate()
        mockTimer = nil
        isCollectingData = false
        #else
        guard let peripheral = connectedPeripheral,
              let characteristic = writeCharacteristic else { return }
        
        isCollectingData = false
        let command: [UInt8] = [0]
        peripheral.writeValue(Data(command), for: characteristic, type: .withResponse)
        #endif
    }
    
    private func simulateDataSync() {
        isSyncing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.isSyncing = false
        }
    }
    
    private func simulateNewReading() {
        // Create mock data
        let mockTimestamp = UInt32(Date().timeIntervalSince1970)
        let mockValues: [UInt16] = [UInt16.random(in: 80...120)]
        
        // Pack data like the real device would
        var mockData = Data()
        mockData.append(contentsOf: withUnsafeBytes(of: mockTimestamp) { Array($0) })
        mockValues.forEach { value in
            mockData.append(contentsOf: withUnsafeBytes(of: value) { Array($0) })
        }
        
        // Use the common handler
        handleSensorData(mockData)
    }
    
    private func syncDeviceTime() {
        #if targetEnvironment(simulator)
        guard let peripheral = connectedPeripheral,
              let characteristic = mockWriteCharacteristic else { return }
        
        let timestamp = Date().timeIntervalSince1970
        var timestampBytes = withUnsafeBytes(of: timestamp) { Array($0) }
        
        peripheral.writeValue(Data(timestampBytes), 
                            for: characteristic, 
                            type: .withResponse)
        #else
        guard let peripheral = connectedPeripheral,
              let characteristic = writeCharacteristic else { return }
        
        let timestamp = Date().timeIntervalSince1970
        var timestampBytes = withUnsafeBytes(of: timestamp) { Array($0) }
        
        peripheral.writeValue(Data(timestampBytes), 
                            for: characteristic, 
                            type: .withResponse)
        #endif
    }
    
    #if !targetEnvironment(simulator)
    private func sendData(_ data: [UInt8]) {
        guard let characteristic = writeCharacteristic,
              let peripheral = connectedPeripheral else {
            errorMessage = "Device not ready"
            return
        }
        peripheral.writeValue(Data(data), for: characteristic, type: .withResponse)
    }
    #endif
    
    func checkMemoryStatus() {
        do {
            let count = try modelContext.fetchCount(FetchDescriptor<SensorData>())
            print("Stored readings: \(count)")
        } catch {
            errorMessage = "Failed to check storage: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Common Methods
    private func handleSensorData(_ data: Data?) {
        guard let data = data else { return }
        
        // Parse the NIRSpectrographyData struct from Arduino
        let timestamp = data.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self) }
        let sensorValues = Array(data.dropFirst(4)).withUnsafeBytes { 
            Array($0.bindMemory(to: UInt16.self)) 
        }
        
        // Create and save sensor readings
        for (index, value) in sensorValues.enumerated() {
            let newReading = SensorData(
                timestamp: Date(timeIntervalSince1970: TimeInterval(timestamp)),
                value: Double(value),
                deviceId: connectedPeripheral?.identifier.uuidString ?? "unknown",
                channelIndex: index
            )
            modelContext.insert(newReading)
        }
        
        try? modelContext.save()
        
        // Send to server (implement your server communication here)
        uploadToServer(sensorValues, timestamp: timestamp)
    }
    
    private func uploadToServer(_ values: [UInt16], timestamp: UInt32) {
        // Implement your server upload logic here
        // This is just a placeholder
        print("Uploading data to server: \(values.count) values at timestamp \(timestamp)")
    }
}

#if targetEnvironment(simulator)
// Mock peripheral for simulator
class MockCharacteristic {
    var value: Data?
}

class MockPeripheral: NSObject, Peripheral {
    let name: String?
    let identifier: UUID
    private var characteristics: [MockCharacteristic] = []
    
    init(name: String) {
        self.name = name
        self.identifier = UUID()
        super.init()
        characteristics = [MockCharacteristic()]
    }
    
    func writeValue(_ data: Data, for characteristic: MockCharacteristic, type: CBCharacteristicWriteType) {
        characteristic.value = data
    }
}
#else
// MARK: - Real Device Extensions
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            errorMessage = "Bluetooth is not available"
        }
    }
    
    func centralManager(_ central: CBCentralManager, 
                       didDiscover peripheral: CBPeripheral,
                       advertisementData: [String : Any], 
                       rssi RSSI: NSNumber) {
        if !discoveredDevices.contains(peripheral) {
            discoveredDevices.append(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, 
                       didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices(serviceUUIDs)
        connectionState = .connected
    }
}

extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, 
                   didDiscoverServices error: Error?) {
        guard error == nil else {
            errorMessage = error?.localizedDescription
            return
        }
        
        peripheral.services?.forEach { service in
            peripheral.discoverCharacteristics(characteristicUUIDs, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, 
                   didUpdateValueFor characteristic: CBCharacteristic, 
                   error: Error?) {
        guard error == nil else {
            errorMessage = error?.localizedDescription
            return
        }
        
        if characteristic.uuid == CBUUID(string: "2A3E") {
            handleSensorData(characteristic.value)
        }
    }
}
#endif
