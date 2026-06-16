import Foundation

struct MultipartFormDataRequest {
    private let boundary = MultipartBoundary.boundary
    var body: MultipartBodyProtocol
    let service: RequestType

    init(service: RequestType, body: MultipartBodyProtocol) {
        self.service = service
        self.body = body
    }

    func build() -> URLRequest? {
        guard let url = buildUrl() else {
            return nil
        }
        var request = URLRequest(url: url)

        request.httpMethod = service.method.rawValue

        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = service.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        var allHeaders = request.allHTTPHeaderFields ?? [:]
        allHeaders.merge(service.customHeaders) { current, _ in current }
        request.allHTTPHeaderFields = allHeaders

        request.httpBody = body.asData()

        return request
    }

    private func buildUrl() -> URL? {
        var components = URLComponents()
        components.scheme = service.scheme
        components.host = service.host
        components.path = service.path
        components.port = service.port

        guard let url = NSString(string: components.url?.absoluteString ?? "").removingPercentEncoding else {
            return nil
        }

        return URL(string: url)
    }
}
