import Foundation

enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case failed(Error)
} 