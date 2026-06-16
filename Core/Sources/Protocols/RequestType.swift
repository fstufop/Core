import Foundation

public protocol RequestType {
    var scheme: String { get }
    var host: String { get }
    var path: String { get }
    var port: Int? { get }
    var method: HTTPMethod { get }
    var customHeaders: [String: String] { get }
    var body: Encodable? { get }
    var queryParams: [String: String]? { get }
    var token: String? { get }
}
