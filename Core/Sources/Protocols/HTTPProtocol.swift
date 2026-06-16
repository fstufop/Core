import Foundation

public protocol HTTPProtocol {
    func request<Model: Decodable>(
        service: RequestType,
        with model: Model.Type,
        decoder: JSONDecoder,
        completion: @escaping (Result<Model, HTTPError>) -> Void
    )

    func multipartRequest<Model: Decodable>(
        service: RequestType,
        with model: Model.Type,
        body: MultipartBodyProtocol,
        decoder: JSONDecoder,
        completion: @escaping (Result<Model?, HTTPError>) -> Void
    )

    func downloadImage(
        from urlString: String,
        completion: @escaping (Result<Data, HTTPError>) -> Void
    )

    func downloadData(
        service: RequestType,
        completion: @escaping (Result<Data, HTTPError>) -> Void
    )

    func cancel(completion: (() -> Void)?)
}
