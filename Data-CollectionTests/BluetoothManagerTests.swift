import XCTest
import CoreBluetooth
@testable import Data_Collection

class BluetoothManagerTests: XCTestCase {
    var mockPeripheral: MockPeripheral!
    var bluetoothManager: BluetoothManager!
    
    override func setUp() {
        super.setUp()
        mockPeripheral = MockPeripheral(delegate: nil, queue: nil)
        bluetoothManager = BluetoothManager(modelContext: createTestModelContext())
    }
    
    func testDeviceDiscovery() {
        // Start scanning
        bluetoothManager.startScanning()
        
        // Wait for device discovery
        let expectation = XCTestExpectation(description: "Device discovered")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            XCTAssertFalse(self.bluetoothManager.discoveredDevices.isEmpty)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 3)
    }
    
    // Add more tests...
} 