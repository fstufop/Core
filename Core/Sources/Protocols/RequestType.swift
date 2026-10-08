import Foundation

public protocol RequestType {
    var scheme: String { get }
    var host: String { get }
    var path: String { get }
    var port: Int? { get }
    var method: NewHTTPMethod { get }
    var customHeaders: [String: String] { get }
    var body: [String: Any]? { get }
    var queryParams: [String: String]? { get }
    var token: String? { get }
    /// Prefix added before the token in the Authorization header (e.g. "Bearer").
    /// Set to nil to send the token without any prefix.
    var tokenPrefix: String? { get }
}

public extension RequestType {
    var tokenPrefix: String? { "Bearer" }
}
