import SwiftUI
import SwiftData
import CoreBluetooth
import Combine
import iOSMcuManager

struct ContentView: View {
    @StateObject private var viewModel: BLEViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var sensorData: [SensorData]
    
    init(modelContext: ModelContext) {
        let bleService = BLEService()
        _viewModel = StateObject(wrappedValue: BLEViewModel(bleService: bleService, modelContext: modelContext))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Status Section
                StatusView(isScanning: viewModel.isScanning, connectionState: viewModel.connectionState)
                
                // Device Scanner
                if viewModel.isScanning {
                    DeviceListView(devices: viewModel.discoveredDevices) { device in
                        viewModel.connect(to: device)
                    }
                }
                
                // Data Display
                if !sensorData.isEmpty {
                    SensorDataView(data: sensorData)
                }
            }
            .padding()
            .navigationTitle("GT TURBO Scanner")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ScanButton(isScanning: viewModel.isScanning) {
                        if viewModel.isScanning {
                            viewModel.stopScanning()
                        } else {
                            viewModel.startScanning()
                        }
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
} 

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: SensorData.self, configurations: config)
    return ContentView(modelContext: container.mainContext)
}
