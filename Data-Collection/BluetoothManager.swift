import Foundation
import iOS_BLE_Library
import Combine

class BluetoothManager: ObservableObject {
    @Published var isScanning = false
    @Published var discoveredDevices: [BLEDevice] = []
    @Published var connectedDevice: BLEDevice?
    @Published var connectionState: ConnectionState = .disconnected
    @Published var errorMessage: String?
    
    private var centralManager: CentralManager?
    private var cancellables = Set<AnyCancellable>()
    private var modelContext: ModelContext?
    
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case failed(Error)
    }
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        setupCentralManager()
    }
    
    private func setupCentralManager() {
        do {
            centralManager = try CentralManager()
            
            // Monitor Bluetooth state changes
            centralManager?.statePublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] state in
                    switch state {
                    case .poweredOn:
                        self?.startScanning()
                    case .poweredOff:
                        self?.errorMessage = "Bluetooth is turned off"
                        self?.stopScanning()
                    case .unauthorized:
                        self?.errorMessage = "Bluetooth permission denied"
                    case .unsupported:
                        self?.errorMessage = "Bluetooth is not supported"
                    default:
                        self?.errorMessage = "Bluetooth is not available"
                    }
                }
                .store(in: &cancellables)
            
            // Monitor discovered peripherals
            centralManager?.discoveredPeripheralPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] peripheral in
                    let device = BLEDevice(peripheral: peripheral)
                    if !(self?.discoveredDevices.contains(where: { $0.id == device.id }) ?? false) {
                        self?.discoveredDevices.append(device)
                    }
                }
                .store(in: &cancellables)
            
        } catch {
            errorMessage = "Failed to initialize Bluetooth: \(error.localizedDescription)"
        }
    }
    
    func startScanning() {
        do {
            // You can specify services to scan for by adding UUIDs
            // let services = [CBUUID(string: "YOUR_SERVICE_UUID")]
            try centralManager?.scanForPeripherals(withServices: nil)
            isScanning = true
        } catch {
            errorMessage = "Failed to start scanning: \(error.localizedDescription)"
        }
    }
    
    func stopScanning() {
        do {
            try centralManager?.stopScan()
            isScanning = false
        } catch {
            errorMessage = "Failed to stop scanning: \(error.localizedDescription)"
        }
    }
    
    func connect(to device: BLEDevice) {
        connectionState = .connecting
        
        centralManager?.connect(device.peripheral)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                switch completion {
                case .finished:
                    self?.connectionState = .connected
                case .failure(let error):
                    self?.connectionState = .failed(error)
                    self?.errorMessage = "Connection failed: \(error.localizedDescription)"
                }
            } receiveValue: { [weak self] _ in
                self?.connectedDevice = device
                self?.discoverServices(for: device)
            }
            .store(in: &cancellables)
    }
    
    private func discoverServices(for device: BLEDevice) {
        device.peripheral.discoverServices(nil)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                switch completion {
                case .finished:
                    print("Services discovered")
                case .failure(let error):
                    self.errorMessage = "Failed to discover services: \(error.localizedDescription)"
                }
            } receiveValue: { services in
                // Handle discovered services
                for service in services {
                    self.discoverCharacteristics(for: service, peripheral: device.peripheral)
                }
            }
            .store(in: &cancellables)
    }
    
    private func discoverCharacteristics(for service: Service, peripheral: Peripheral) {
        peripheral.discoverCharacteristics(nil, for: service)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                switch completion {
                case .finished:
                    print("Characteristics discovered for service: \(service.uuid)")
                case .failure(let error):
                    self.errorMessage = "Failed to discover characteristics: \(error.localizedDescription)"
                }
            } receiveValue: { characteristics in
                // Handle discovered characteristics
                for characteristic in characteristics {
                    if characteristic.properties.contains(.notify) {
                        self.enableNotifications(for: characteristic, peripheral: peripheral)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func enableNotifications(for characteristic: Characteristic, peripheral: Peripheral) {
        peripheral.observeValue(for: characteristic)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                switch completion {
                case .finished:
                    print("Notifications completed for: \(characteristic.uuid)")
                case .failure(let error):
                    self.errorMessage = "Notification error: \(error.localizedDescription)"
                }
            } receiveValue: { data in
                // Handle received data
                self.handleReceivedData(data, from: characteristic)
            }
            .store(in: &cancellables)
    }
    
    private func handleReceivedData(_ data: Data, from characteristic: Characteristic) {
        // Process the received data based on your microcontroller's data format
        // For example, if sending a double value:
        if data.count >= 8 {
            let value = data.withUnsafeBytes { $0.load(as: Double.self) }
            saveReading(value: value)
        }
    }
    
    private func saveReading(value: Double) {
        guard let deviceId = connectedDevice?.id.uuidString,
              let modelContext = modelContext else { return }
        
        let reading = SensorData(
            timestamp: Date(),
            value: value,
            deviceId: deviceId,
            isSynced: false
        )
        
        modelContext.insert(reading)
        
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to save reading: \(error.localizedDescription)"
        }
    }
}