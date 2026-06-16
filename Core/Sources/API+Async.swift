import Foundation

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
extension API {
    public func request<Model: Decodable>(
        service: RequestType,
        with model: Model.Type,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> Model {
        try await withCheckedThrowingContinuation { continuation in
            request(service: service, with: model, decoder: decoder) { result in
                switch result {
                case .success(let value): continuation.resume(returning: value)
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }

    public func multipartRequest<Model: Decodable>(
        service: RequestType,
        with model: Model.Type,
        body: MultipartBodyProtocol,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> Model? {
        try await withCheckedThrowingContinuation { continuation in
            multipartRequest(service: service, with: model, body: body, decoder: decoder) { result in
                switch result {
                case .success(let value): continuation.resume(returning: value)
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }

    public func downloadImage(from urlString: String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            downloadImage(from: urlString) { result in
                switch result {
                case .success(let data): continuation.resume(returning: data)
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }

    public func downloadData(service: RequestType) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            downloadData(service: service) { result in
                switch result {
                case .success(let data): continuation.resume(returning: data)
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }
}
