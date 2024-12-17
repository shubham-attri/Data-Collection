import Foundation
import iOS_BLE_Library
import Combine

class BluetoothManager: ObservableObject {
    @Published var isScanning = false
    @Published var discoveredDevices: [BLEDevice] = []
    @Published var connectedDevice: BLEDevice?
    
    private var centralManager: CentralManager?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupCentralManager()
    }
    
    private func setupCentralManager() {
        centralManager = CentralManager()
        
        // Monitor state changes
        centralManager?.statePublisher
            .sink { [weak self] state in
                if state == .poweredOn {
                    self?.startScanning()
                }
            }
            .store(in: &cancellables)
        
        // Monitor discovered devices
        centralManager?.discoveredPeripheralPublisher
            .sink { [weak self] peripheral in
                let device = BLEDevice(peripheral: peripheral)
                if !self?.discoveredDevices.contains(where: { $0.id == device.id }) ?? false {
                    self?.discoveredDevices.append(device)
                }
            }
            .store(in: &cancellables)
    }
    
    func startScanning() {
        centralManager?.scanForPeripherals(withServices: nil)
        isScanning = true
    }
    
    func stopScanning() {
        centralManager?.stopScan()
        isScanning = false
    }
    
    func connect(to device: BLEDevice) {
        centralManager?.connect(device.peripheral)
            .sink { completion in
                switch completion {
                case .finished:
                    print("Connection completed")
                case .failure(let error):
                    print("Connection failed: \(error)")
                }
            } receiveValue: { [weak self] _ in
                self?.connectedDevice = device
            }
            .store(in: &cancellables)
    }
}