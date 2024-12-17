//
//  ContentView.swift
//  Data-Collection
//
//  Created by Shubham Attri on 16/12/24.
//

import SwiftUI
import SwiftData
import iOS_BLE_Library

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var bluetoothManager: BluetoothManager
    @Query private var sensorData: [SensorData]
    
    init(modelContext: ModelContext) {
        _bluetoothManager = StateObject(wrappedValue: BluetoothManager(modelContext: modelContext))
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if let errorMessage = bluetoothManager.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
                
                // Device Scanner
                if bluetoothManager.isScanning {
                    List(bluetoothManager.discoveredDevices) { device in
                        Button(action: {
                            bluetoothManager.connect(to: device)
                        }) {
                            HStack {
                                Text(device.name)
                                Spacer()
                                if case .connecting = bluetoothManager.connectionState {
                                    ProgressView()
                                }
                            }
                        }
                    }
                }
                
                // Connected Device Status
                if let device = bluetoothManager.connectedDevice {
                    VStack {
                        Text("Connected to: \(device.name)")
                        switch bluetoothManager.connectionState {
                        case .connected:
                            Text("Status: Connected")
                                .foregroundColor(.green)
                        case .connecting:
                            Text("Status: Connecting...")
                                .foregroundColor(.orange)
                        case .failed(let error):
                            Text("Status: Failed - \(error.localizedDescription)")
                                .foregroundColor(.red)
                        case .disconnected:
                            Text("Status: Disconnected")
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                }
                
                // Collected Data List
                List {
                    ForEach(sensorData) { data in
                        VStack(alignment: .leading) {
                            Text("Value: \(data.value)")
                            Text("Time: \(data.timestamp, format: .dateTime)")
                            Text("Synced: \(data.isSynced ? "Yes" : "No")")
                                .foregroundColor(data.isSynced ? .green : .red)
                        }
                    }
                    .onDelete(perform: deleteSensorData)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        bluetoothManager.isScanning ? bluetoothManager.stopScanning() : bluetoothManager.startScanning()
                    }) {
                        Text(bluetoothManager.isScanning ? "Stop Scanning" : "Start Scanning")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: syncData) {
                        Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            }
            .navigationTitle("Data Collection")
        }
    }
    
    private func deleteSensorData(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(sensorData[index])
            }
        }
    }
    
    private func syncData() {
        // TODO: Implement server sync logic
        let unsyncedData = sensorData.filter { !$0.isSynced }
        // Add your server communication logic here
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: [Item.self, SensorData.self], configurations: config)
    return ContentView(modelContext: container.mainContext)
}

