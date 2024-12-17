//
//  ContentView.swift
//  Data-Collection
//
//  Created by Shubham Attri on 16/12/24.
//

import SwiftUI
import SwiftData
import CoreBluetooth

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var bluetoothManager: BluetoothManager
    @Query(sort: \SensorData.timestamp, order: .reverse) private var sensorData: [SensorData]
    @State private var isCollecting = false
    
    init(modelContext: ModelContext) {
        _bluetoothManager = StateObject(wrappedValue: BluetoothManager(modelContext: modelContext))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Status Section
                statusSection
                
                // Device Scanner
                if bluetoothManager.isScanning {
                    deviceListSection
                }
                
                // Connected Device Controls
                if case .connected = bluetoothManager.connectionState {
                    connectedDeviceSection
                }
                
                // Data Display
                if !sensorData.isEmpty {
                    dataDisplaySection
                }
            }
            .padding()
            .navigationTitle("GT TURBO Scanner")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    scanButton
                }
            }
            .alert("Error", isPresented: .constant(bluetoothManager.errorMessage != nil)) {
                Button("OK") { bluetoothManager.errorMessage = nil }
            } message: {
                Text(bluetoothManager.errorMessage ?? "")
            }
        }
    }
    
    private var statusSection: some View {
        HStack {
            Image(systemName: bluetoothManager.isScanning ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                .foregroundColor(bluetoothManager.isScanning ? .blue : .gray)
            Text(bluetoothManager.isScanning ? "Scanning for GT TURBO..." : "Scan for GT TURBO")
            if case .connecting = bluetoothManager.connectionState {
                ProgressView()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var deviceListSection: some View {
        List(bluetoothManager.discoveredDevices, id: \.identifier) { (device: CBPeripheral) in
            Button(action: { bluetoothManager.connect(to: device) }) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(device.name ?? "Unknown Device")
                            .font(.headline)
                        Text(device.identifier.uuidString)
                            .font(.caption)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                }
            }
            .disabled(device.name != "GT TURBO")
        }
    }
    
    private var connectedDeviceSection: some View {
        VStack(spacing: 15) {
            Text("Battery: \(bluetoothManager.batteryLevel)%")
                .font(.headline)
            
            HStack(spacing: 20) {
                Button(action: {
                    isCollecting.toggle()
                    if isCollecting {
                        bluetoothManager.startDataCollection()
                    } else {
                        bluetoothManager.stopDataCollection()
                    }
                }) {
                    Label(isCollecting ? "Stop" : "Start", systemImage: isCollecting ? "stop.fill" : "play.fill")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.borderless)
                .background(isCollecting ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                .cornerRadius(8)
                
                Button(action: {
                    bluetoothManager.checkMemoryStatus()
                }) {
                    Label("Check Memory", systemImage: "memorychip")
                }
                .buttonStyle(.borderless)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var dataDisplaySection: some View {
        List {
            ForEach(sensorData.prefix(5)) { data in
                VStack(alignment: .leading) {
                    Text("Sensor: \(data.deviceId)")
                    Text("Value: \(String(format: "%.2f", data.value))")
                    Text(data.timestamp.formatted())
                        .font(.caption)
                }
            }
        }
    }
    
    private var scanButton: some View {
        Button(action: {
            bluetoothManager.isScanning ? bluetoothManager.stopScanning() : bluetoothManager.startScanning()
        }) {
            Image(systemName: bluetoothManager.isScanning ? "stop.circle.fill" : "play.circle.fill")
                .font(.title2)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: SensorData.self, configurations: config)
    return ContentView(modelContext: container.mainContext)
}

