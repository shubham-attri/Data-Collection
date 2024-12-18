import Foundation
import CoreBluetooth
import Combine
import SwiftData

@MainActor
class BLEViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var isScanning = false
    @Published private(set) var discoveredDevices: [CBPeripheral] = []
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var errorMessage: String?
    
    // MARK: - Private Properties
    private let bleService: BLEServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private let modelContext: ModelContext
    
    // MARK: - Initialization
    init(bleService: BLEServiceProtocol, modelContext: ModelContext) {
        self.bleService = bleService
        self.modelContext = modelContext
        setupSubscriptions()
    }
    
    // MARK: - Private Methods
    private func setupSubscriptions() {
        bleService.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                if state != .poweredOn {
                    self?.errorMessage = "Bluetooth is not available"
                }
            }
            .store(in: &cancellables)
        
        bleService.discoveredDevicesPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.discoveredDevices, on: self)
            .store(in: &cancellables)
        
        bleService.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.connectionState = state
                if case .failed(let error) = state {
                    self?.errorMessage = error.localizedDescription
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func startScanning() {
        isScanning = true
        bleService.startScanning()
    }
    
    func stopScanning() {
        isScanning = false
        bleService.stopScanning()
    }
    
    func connect(to peripheral: CBPeripheral) {
        bleService.connect(peripheral)
    }
    
    func disconnect() {
        bleService.disconnect()
    }
    
    func saveSensorData(_ value: Double, from deviceId: String) {
        let sensorData = SensorData(
            value: value,
            deviceId: deviceId
        )
        modelContext.insert(sensorData)
        
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to save sensor data: \(error.localizedDescription)"
        }
    }
} 