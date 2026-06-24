import Foundation

public enum HeaderBuilder {
    case basic(token: String?, tokenPrefix: String?)

    public func build(customHeaders: [String: String]? = nil) -> [String: String] {
        switch self {
        case .basic(let token, let tokenPrefix):
            return basicHeader(with: token, tokenPrefix: tokenPrefix, customHeaders: customHeaders)
        }
    }

    private func basicHeader(with token: String?, tokenPrefix: String?, customHeaders: [String: String]? = nil) -> [String: String] {
        var headers: [String: String] = ["Content-Type": "application/json"]
        if let token = token {
            let authValue = tokenPrefix.map { "\($0) \(token)" } ?? token
            headers["Authorization"] = authValue
        }
        if let customHeaders = customHeaders {
            headers.merge(customHeaders) { (_, new) in new }
        }
        return headers
    }
}
