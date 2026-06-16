import Foundation

public class API: HTTPProtocol {
    private let taskLock = NSLock()
    private var _requestTask: URLSessionDataTaskProtocol?
    private var requestTask: URLSessionDataTaskProtocol? {
        get {
            taskLock.lock()
            defer { taskLock.unlock() }
            return _requestTask
        }
        set {
            taskLock.lock()
            defer { taskLock.unlock() }
            _requestTask = newValue
        }
    }
    private var session: URLSessionProtocol
    private let isConnected: () -> Bool

    public init(
        session: URLSessionProtocol = URLSession.shared,
        requestTask: URLSessionDataTaskProtocol? = nil,
        connectivityCheck: (() -> Bool)? = nil
    ) {
        self.session = session
        self._requestTask = requestTask
        self.isConnected = connectivityCheck ?? ConnectionCheck.isConnectedToNetwork
    }

    public func request<Model: Decodable>(
        service: RequestType,
        with model: Model.Type,
        decoder: JSONDecoder = JSONDecoder(),
        completion: @escaping (Result<Model, HTTPError>) -> Void
    ) {
        guard let urlRequest = try? RequestBuilder.build(from: service) else {
            completion(.failure(.noData))
            return
        }

        guard isConnected() else {
            completion(.failure(.noInternet))
            return
        }

        requestTask = session.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                completion(.failure(.requestError(error)))
                return
            }

            guard let data = data, let response = response as? HTTPURLResponse else {
                completion(.failure(.unknown))
                return
            }

            do {
                try ErrorResponseBuilder.build(from: response, error: nil, data: data)
                let object = try HTTPDecodeBuilder.build(from: data, objectType: Model.self, decoder: decoder)
                completion(.success(object))
                PrintBuilder.prettyPrint(request: urlRequest, response: response, data: data)
            } catch let httpError as HTTPError {
                completion(.failure(httpError))
                PrintBuilder.prettyPrint(request: urlRequest, response: response, data: data)
            } catch {
                completion(.failure(.requestError(error)))
                PrintBuilder.prettyPrint(request: urlRequest, response: response, data: data)
            }
        }
        requestTask?.resume()
    }

    public func multipartRequest<Model: Decodable>(
        service: RequestType,
        with model: Model.Type,
        body: MultipartBodyProtocol,
        decoder: JSONDecoder = JSONDecoder(),
        completion: @escaping (Result<Model?, HTTPError>) -> Void
    ) {
        guard let request = MultipartFormDataRequest(service: service, body: body).build() else {
            completion(.failure(.requestFormDataError))
            return
        }

        requestTask = session.dataTask(with: request) { responseData, response, error in
            if let error = error {
                completion(.failure(.requestError(error)))
                return
            }

            guard let responseData = responseData,
                  let response = response as? HTTPURLResponse else {
                completion(.failure(.unknown))
                return
            }

            do {
                try ErrorResponseBuilder.build(from: response, error: nil, data: responseData)
                let object = try HTTPDecodeBuilder.build(from: responseData, objectType: Model.self, decoder: decoder)
                completion(.success(object))
            } catch let httpError as HTTPError {
                completion(.failure(httpError))
            } catch {
                completion(.failure(.requestError(error)))
            }

            PrintBuilder.prettyPrint(request: request, response: response, data: responseData, printBody: false)
        }
        requestTask?.resume()
    }

    public func downloadImage(
        from urlString: String,
        completion: @escaping (Result<Data, HTTPError>) -> Void
    ) {
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidImageURL))
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"

        requestTask = session.dataTask(with: urlRequest) { data, _, error in
            if let error = error {
                completion(.failure(.requestError(error)))
                return
            }
            guard let data = data else {
                completion(.failure(.downloadImageError))
                return
            }
            completion(.success(data))
        }
        requestTask?.resume()
    }

    public func downloadData(
        service: RequestType,
        completion: @escaping (Result<Data, HTTPError>) -> Void
    ) {
        guard let urlRequest = try? RequestBuilder.build(from: service) else {
            completion(.failure(.noData))
            return
        }

        guard isConnected() else {
            completion(.failure(.noInternet))
            return
        }

        requestTask = session.dataTask(with: urlRequest) { data, _, error in
            if let error = error {
                completion(.failure(.requestError(error)))
                return
            }
            guard let data = data else {
                completion(.failure(.unknown))
                return
            }
            completion(.success(data))
        }
        requestTask?.resume()
    }

    public func cancel(completion: (() -> Void)?) {
        requestTask?.cancel()
        session.getAllTasks { tasks in
            tasks.forEach { $0.cancel() }
            completion?()
        }
    }

    public func cancel(path: String, completion: (() -> Void)?) {
        session.getAllTasks { tasks in
            tasks.forEach { task in
                if let url = task.originalRequest?.url?.absoluteString, url.contains(path) {
                    task.cancel()
                }
            }
            completion?()
        }
    }
}
