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
    @StateObject private var bluetoothManager = BluetoothManager()
    @Query private var sensorData: [SensorData]
    
    var body: some View {
        NavigationStack {
            VStack {
                // Device Scanner
                if bluetoothManager.isScanning {
                    List(bluetoothManager.discoveredDevices) { device in
                        Button(action: {
                            bluetoothManager.connect(to: device)
                        }) {
                            Text(device.name)
                        }
                    }
                }
                
                // Connected Device Status
                if let device = bluetoothManager.connectedDevice {
                    VStack {
                        Text("Connected to: \(device.name)")
                        Text("Status: Connected")
                            .foregroundColor(.green)
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
    ContentView()
        .modelContainer(for: [Item.self, SensorData.self], inMemory: true)
}

