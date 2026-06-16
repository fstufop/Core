import Foundation

public protocol URLSessionDataTaskProtocol {
    var identifier: Int { get }
    func resume()
    func cancel()
}

extension URLSessionDataTask: URLSessionDataTaskProtocol {
    public var identifier: Int {
        get {
            self.taskIdentifier
        }
    }
}
