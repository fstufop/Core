import Foundation

enum RequestBuilder {
    static func build(from service: RequestType) throws -> URLRequest {
        var components = URLComponents()
        components.scheme = service.scheme
        components.host = service.host
        components.path = service.path
        components.port = service.port
        
        if let params = service.queryParams {
            components.queryItems = params.map { key, value in
                return URLQueryItem(name: key, value: value)
            }
        }
        
        var headers = HeaderBuilder.basic(token: service.token).build()
        headers.merge(service.customHeaders) { current, _ in current }
        
        guard let urlString = components.url?.absoluteString.removingPercentEncoding,
              let url = URL(string: urlString) else {
            throw HTTPError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = headers
        request.httpMethod = service.method.rawValue
        
        if let body = service.body,
           service.method != .get {
            let encoder = try JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
            request.httpBody = encoder
        }
        
        return request
    }
}
