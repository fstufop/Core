import Network

final class ConnectionCheck {
    private static let shared = ConnectionCheck()

    private let monitor = NWPathMonitor()
    private var currentStatus: NWPath.Status = .requiresConnection

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.currentStatus = path.status
        }
        monitor.start(queue: DispatchQueue(label: "com.core.network-monitor"))
    }

    static func isConnectedToNetwork() -> Bool {
        return shared.currentStatus == .satisfied
    }
}
