import SwiftUI

struct SensorDataView: View {
    let data: [SensorData]
    
    var body: some View {
        List {
            ForEach(Array(data.prefix(5))) { data in
                VStack(alignment: .leading) {
                    Text("Sensor: \(data.deviceId)")
                    Text("Value: \(String(format: "%.2f", data.value))")
                    Text(data.timestamp.formatted())
                }
            }
        }
    }
} 