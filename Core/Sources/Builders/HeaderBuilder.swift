import Foundation

public enum HeaderBuilder {
    case basic(token: String?)
    
    public func build(customHeaders: [String: String]? = nil) -> [String: String] {
        switch self {
        case .basic(let token):
            return basicHeader(with: token, customHeaders: customHeaders)
        }
    }
    
    private func basicHeader(with token: String?, customHeaders: [String: String]? = nil) -> [String: String] {
        var headers: [String: String] = ["Content-Type": "application/json"]
        if let token = token {
            headers["Authorization"] = "Bearer \(token)"
        }
        if let customHeaders = customHeaders {
            headers.merge(customHeaders) { (_, new) in new }
        }
        return headers
    }
}
