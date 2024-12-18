import SwiftUI
import CoreBluetooth

struct DeviceListView: View {
    let devices: [CBPeripheral]
    let onDeviceSelected: (CBPeripheral) -> Void
    
    var body: some View {
        List(devices, id: \.identifier) { device in
            Button(action: { onDeviceSelected(device) }) {
                HStack {
                    Text(device.name ?? "Unknown Device")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
            }
        }
    }
} 