import CoreBluetooth

class MockPeripheral: CBPeripheralManager, CBPeripheralManagerDelegate {
    private var writeCharacteristic: CBMutableCharacteristic?
    private var notifyCharacteristic: CBMutableCharacteristic?
    private var batteryCharacteristic: CBMutableCharacteristic?
    
    override init(delegate: CBPeripheralManagerDelegate?, queue: DispatchQueue?) {
        super.init(delegate: self, queue: queue)
        setupServices()
    }
    
    private func setupServices() {
        // Battery Service
        batteryCharacteristic = CBMutableCharacteristic(
            type: CBUUID(string: "2A19"),
            properties: .read,
            value: Data([75]), // 75% battery
            permissions: .readable
        )
        
        let batteryService = CBMutableService(type: CBUUID(string: "180F"), primary: true)
        batteryService.characteristics = [batteryCharacteristic!]
        
        // Write Service
        writeCharacteristic = CBMutableCharacteristic(
            type: CBUUID(string: "2A3D"),
            properties: [.write, .writeWithoutResponse],
            value: nil,
            permissions: .writeable
        )
        
        let writeService = CBMutableService(type: CBUUID(string: "1818"), primary: true)
        writeService.characteristics = [writeCharacteristic!]
        
        // Read/Notify Service
        notifyCharacteristic = CBMutableCharacteristic(
            type: CBUUID(string: "2A3E"),
            properties: [.notify, .read],
            value: nil,
            permissions: .readable
        )
        
        let readService = CBMutableService(type: CBUUID(string: "1819"), primary: true)
        readService.characteristics = [notifyCharacteristic!]
        
        // Add all services
        add(batteryService)
        add(writeService)
        add(readService)
    }
    
    // MARK: - CBPeripheralManagerDelegate
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            startAdvertising([
                CBAdvertisementDataServiceUUIDsKey: [
                    CBUUID(string: "180F"),
                    CBUUID(string: "1818"),
                    CBUUID(string: "1819")
                ],
                CBAdvertisementDataLocalNameKey: "NIR Test Device"
            ])
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if let data = request.value {
                handleWriteRequest(data)
            }
            peripheral.respond(to: request, withResult: .success)
        }
    }
    
    // MARK: - Test Helpers
    private func handleWriteRequest(_ data: Data) {
        guard let command = data.first else { return }
        
        switch command {
        case 0x01: // Check memory
            sendNotification(Data([0x01])) // Has data
            
        case 0x02: // Request stored data
            // Send mock sensor data
            let timestamp = UInt32(Date().timeIntervalSince1970 * 1000)
            var mockData = withUnsafeBytes(of: timestamp) { Data($0) }
            
            // Add 18 mock sensor values
            for i in 0..<18 {
                let value = UInt16(i * 100)
                mockData.append(contentsOf: withUnsafeBytes(of: value) { Array($0) })
            }
            
            sendNotification(mockData)
            
        case 0x03: // Start collection
            // Start sending periodic updates
            startPeriodicUpdates()
            
        case 0x04: // Stop collection
            // Stop periodic updates
            stopPeriodicUpdates()
            
        default:
            break
        }
    }
    
    private func sendNotification(_ data: Data) {
        guard let characteristic = notifyCharacteristic else { return }
        peripheralManager(self, didReceiveRead: CBATTRequest(
            characteristic: characteristic,
            offset: 0
        ))
    }
    
    private var updateTimer: Timer?
    
    private func startPeriodicUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            let timestamp = UInt32(Date().timeIntervalSince1970 * 1000)
            var mockData = withUnsafeBytes(of: timestamp) { Data($0) }
            
            // Add 18 mock sensor values
            for i in 0..<18 {
                let value = UInt16(Int.random(in: 0...1000))
                mockData.append(contentsOf: withUnsafeBytes(of: value) { Array($0) })
            }
            
            self?.sendNotification(mockData)
        }
    }
    
    private func stopPeriodicUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
} 