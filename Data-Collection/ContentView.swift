//
//  ContentView.swift
//  Data-Collection
//
//  Created by Shubham Attri on 16/12/24.
//

import SwiftUI
import SwiftData
import CoreBluetooth
import Combine
import os.log  // For logging


// Move ViewLayout outside ContentView to make it accessible to all views
private enum ViewLayout {
    static let minimumTapArea: CGFloat = 44
    static let cardCornerRadius: CGFloat = 16
    static let standardPadding: CGFloat = 16
    static let cardSpacing: CGFloat = 20
    static let textSpacing: CGFloat = 4
    static let sectionSpacing: CGFloat = 24
    static let listItemSpacing: CGFloat = 12
}

// Update SharedStyles to use UIKit.UIColor explicitly
private struct SharedStyles {
    static var backgroundStyle: some ShapeStyle {
        Color(uiColor: UIColor.systemBackground)
    }
    
    static var secondaryBackgroundStyle: some ShapeStyle {
        Color(uiColor: UIColor.secondarySystemBackground)
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var bluetoothManager: BluetoothManager
    
    // Fix Query syntax with explicit type
    @Query(sort: \SensorData.timestamp, order: .reverse) 
    private var sensorData: [SensorData]
    
    @State private var isCollecting = false
    
    init(modelContext: ModelContext) {
        // Initialize BluetoothManager
        _bluetoothManager = StateObject(
            wrappedValue: BluetoothManager(modelContext: modelContext)
        )
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: ViewLayout.sectionSpacing) {
                // Status Card
                statusCard
                
                // Main Content
                Group {
                    if bluetoothManager.isScanning {
                        deviceListCard
                    } else if case .connected = bluetoothManager.connectionState {
                        connectedDeviceCard
                    } else {
                        startScanningCard
                    }
                }
                
                // Data Display
                if !sensorData.isEmpty {
                    dataDisplayCard
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("GT TURBO Scanner")
            .alert("Error", isPresented: .constant(bluetoothManager.errorMessage != nil)) {
                Button("OK") { bluetoothManager.errorMessage = nil }
            } message: {
                Text(bluetoothManager.errorMessage ?? "")
            }
        }
    }
    
    private var statusCard: some View {
        VStack(spacing: ViewLayout.standardPadding) {
            HStack(spacing: ViewLayout.standardPadding) {
                // Status Icon
                Image(systemName: bluetoothManager.isScanning ? 
                      "antenna.radiowaves.left.and.right.circle.fill" : 
                      "antenna.radiowaves.left.and.right.slash.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(bluetoothManager.isScanning ? .blue : .gray)
                    .frame(width: ViewLayout.minimumTapArea, height: ViewLayout.minimumTapArea)
                    .contentShape(Rectangle())
                
                // Status Text
                VStack(alignment: .leading, spacing: ViewLayout.textSpacing) {
                    Text(bluetoothManager.isScanning ? "Scanning..." : "Ready to Scan")
                        .font(.headline)
                    Text(connectionStateText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Scan Button - Following Apple's 44x44pt minimum touch target
                Button(action: {
                    if bluetoothManager.isScanning {
                        bluetoothManager.stopScanning()
                    } else {
                        bluetoothManager.startScanning()
                    }
                }) {
                    Image(systemName: bluetoothManager.isScanning ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(bluetoothManager.isScanning ? .red : .blue)
                        .frame(width: ViewLayout.minimumTapArea, height: ViewLayout.minimumTapArea)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(bluetoothManager.isScanning ? "Stop Scanning" : "Start Scanning")
                
                // Progress Indicator
                if case .connecting = bluetoothManager.connectionState {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: ViewLayout.minimumTapArea, height: ViewLayout.minimumTapArea)
                }
            }
        }
        .padding(ViewLayout.standardPadding)
        .background(
            RoundedRectangle(cornerRadius: ViewLayout.cardCornerRadius)
                .fill(SharedStyles.backgroundStyle)
                .shadow(color: .gray.opacity(0.2), radius: 8)
        )
    }
    
    private var deviceListCard: some View {
        VStack(alignment: .leading, spacing: ViewLayout.listItemSpacing) {
            Text("Available Devices")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            ScrollView {
                LazyVStack(spacing: ViewLayout.listItemSpacing) {
                    #if targetEnvironment(simulator)
                    ForEach(bluetoothManager.discoveredDevices, id: \MockPeripheral.identifier) { device in
                        DeviceRow(device: device) {
                            bluetoothManager.connect(to: device)
                        }
                        .disabled(device.name != "GT TURBO")
                    }
                    #else
                    ForEach(bluetoothManager.discoveredDevices, id: \CBPeripheral.identifier) { device in
                        DeviceRow(device: device) {
                            bluetoothManager.connect(to: device)
                        }
                        .disabled(device.name != "GT TURBO")
                    }
                    #endif
                }
                .padding(.horizontal)
            }
        }
        .frame(maxHeight: 300)
        .background(
            RoundedRectangle(cornerRadius: ViewLayout.cardCornerRadius)
                .fill(SharedStyles.backgroundStyle)
                .shadow(color: .gray.opacity(0.2), radius: 8)
        )
    }
    
    private var startScanningCard: some View {
        VStack(spacing: ViewLayout.sectionSpacing) {
            Image(systemName: "bluetooth.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            Text("Start Scanning")
                .font(.headline)
            
            Text("Tap the scan button to search for GT TURBO devices")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(SharedStyles.backgroundStyle)
                .shadow(color: .gray.opacity(0.2), radius: 8)
        )
    }
    
    private var connectedDeviceCard: some View {
        VStack(spacing: ViewLayout.sectionSpacing) {
            HStack {
                VStack(alignment: .leading, spacing: ViewLayout.textSpacing) {
                    Text("Connected Device")
                        .font(.headline)
                    Text(connectedPeripheralName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                BatteryIndicator(level: Int(bluetoothManager.batteryLevel))
            }
            
            Divider()
            
            HStack(spacing: ViewLayout.sectionSpacing) {
                Button(action: {
                    isCollecting.toggle()
                    if isCollecting {
                        bluetoothManager.startDataCollection()
                    } else {
                        bluetoothManager.stopDataCollection()
                    }
                }) {
                    Label(isCollecting ? "Stop Collection" : "Start Collection", 
                          systemImage: isCollecting ? "stop.circle.fill" : "play.circle.fill")
                        .frame(maxWidth: .infinity)
                        .frame(height: ViewLayout.minimumTapArea)
                }
                .buttonStyle(.borderedProminent)
                .tint(isCollecting ? .red : .blue)
                
                Button(action: {
                    bluetoothManager.checkMemoryStatus()
                }) {
                    Label("Memory Status", systemImage: "memorychip")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(SharedStyles.backgroundStyle)
                .shadow(color: .gray.opacity(0.2), radius: 8)
        )
    }
    
    private var dataDisplayCard: some View {
        VStack(alignment: .leading, spacing: ViewLayout.listItemSpacing) {
            Text("Recent Readings")
                .font(.headline)
            
            ForEach(Array(sensorData.prefix(5))) { data in
                DataRow(data: data)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(SharedStyles.backgroundStyle)
                .shadow(color: .gray.opacity(0.2), radius: 8)
        )
    }
    
    // Helper computed properties
    private var connectionStateText: String {
        switch bluetoothManager.connectionState {
        case .disconnected: return "Not Connected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        }
    }
    
    private var connectedPeripheralName: String {
        bluetoothManager.connectedPeripheral?.name ?? "Unknown Device"
    }
}

// MARK: - Supporting Views
struct DeviceRow: View {
    #if targetEnvironment(simulator)
    let device: MockPeripheral
    #else
    let device: CBPeripheral
    #endif
    let onConnect: () -> Void
    
    var body: some View {
        Button(action: onConnect) {
            HStack {
                VStack(alignment: .leading) {
                    Text(device.name ?? "Unknown Device")
                        .font(.body)
                    Text(device.identifier.uuidString)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.blue)
            }
            .padding()
            .frame(minHeight: ViewLayout.minimumTapArea)
            .background(
                RoundedRectangle(cornerRadius: ViewLayout.cardCornerRadius)
                    .fill(SharedStyles.secondaryBackgroundStyle)
            )
        }
        .accessibilityLabel(device.name ?? "Unknown Device")
        .accessibilityHint("Double tap to connect to this device")
    }
}

struct DataRow: View {
    let data: SensorData
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Value: \(String(format: "%.2f", data.value))")
                    .font(.body)
                Text(data.timestamp.formatted())
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("Channel \(data.channelIndex)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct BatteryIndicator: View {
    let level: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: batteryIcon)
                .foregroundColor(batteryColor)
            Text("\(level)%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .accessibilityLabel("Battery level \(level) percent")
        .accessibilityAddTraits(.updatesFrequently)
    }
    
    private var batteryIcon: String {
        switch level {
        case 0...20: return "battery.0"
        case 21...40: return "battery.25"
        case 41...60: return "battery.50"
        case 61...80: return "battery.75"
        default: return "battery.100"
        }
    }
    
    private var batteryColor: Color {
        switch level {
        case 0...20: return .red
        case 21...40: return .orange
        default: return .green
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: SensorData.self,
        configurations: config
    )
    
    ContentView(modelContext: container.mainContext)
        .modelContainer(container)
}

