import SwiftUI

struct ScanButton: View {
    let isScanning: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: isScanning ? "stop.circle.fill" : "play.circle.fill")
                .foregroundColor(isScanning ? .red : .blue)
        }
    }
} 