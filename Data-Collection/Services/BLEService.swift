import Foundation
import CoreBluetooth
import Combine

enum BLEServiceError: Error {
    case bluetoothUnavailable
    case deviceNotFound
    case connectionFailed(Error)
    case serviceNotFound
    case characteristicNotFound
}

protocol BLEServiceProtocol {
    var statePublisher: AnyPublisher<CBManagerState, Never> { get }
    var discoveredDevicesPublisher: AnyPublisher<[CBPeripheral], Never> { get }
    var connectionStatePublisher: AnyPublisher<ConnectionState, Never> { get }
    
    func startScanning()
    func stopScanning()
    func connect(_ peripheral: CBPeripheral)
    func disconnect()
}

class BLEService: NSObject, BLEServiceProtocol {
    // MARK: - Properties
    private var centralManager: CBCentralManager!
    private let stateSubject = PassthroughSubject<CBManagerState, Never>()
    private let devicesSubject = CurrentValueSubject<[CBPeripheral], Never>([])
    private let connectionStateSubject = CurrentValueSubject<ConnectionState, Never>(.disconnected)
    
    // MARK: - Publishers
    var statePublisher: AnyPublisher<CBManagerState, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    
    var discoveredDevicesPublisher: AnyPublisher<[CBPeripheral], Never> {
        devicesSubject.eraseToAnyPublisher()
    }
    
    var connectionStatePublisher: AnyPublisher<ConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Public Methods
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            stateSubject.send(centralManager.state)
            return
        }
        centralManager.scanForPeripherals(withServices: nil)
    }
    
    func stopScanning() {
        centralManager.stopScan()
    }
    
    func connect(_ peripheral: CBPeripheral) {
        connectionStateSubject.send(.connecting)
        centralManager.connect(peripheral)
    }
    
    func disconnect() {
        guard let peripheral = devicesSubject.value.first(where: { centralManager.isConnected($0) }) else { return }
        centralManager.cancelPeripheralConnection(peripheral)
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        stateSubject.send(central.state)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if !devicesSubject.value.contains(peripheral) {
            var devices = devicesSubject.value
            devices.append(peripheral)
            devicesSubject.send(devices)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionStateSubject.send(.connected)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionStateSubject.send(.failed(error ?? BLEServiceError.connectionFailed(NSError(domain: "com.datacollection", code: -1))))
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectionStateSubject.send(.disconnected)
    }
} 