import SwiftUI

struct StatusView: View {
    let isScanning: Bool
    let connectionState: ConnectionState
    
    var body: some View {
        HStack {
            Image(systemName: isScanning ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                .foregroundColor(isScanning ? .blue : .gray)
            Text(statusText)
            if case .connecting = connectionState {
                ProgressView()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var statusText: String {
        switch connectionState {
        case .disconnected:
            return isScanning ? "Scanning for GT TURBO..." : "Scan for GT TURBO"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .failed:
            return "Connection Failed"
        }
    }
} 