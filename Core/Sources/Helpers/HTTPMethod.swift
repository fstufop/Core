import Foundation

public enum HTTPMethod: String, Equatable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

@available(*, deprecated, renamed: "HTTPMethod")
public typealias NewHTTPMethod = HTTPMethod
