import UIKit

public class API: HTTPProtocol {
    private var requestTask: URLSessionDataTaskProtocol?
    private var session: URLSessionProtocol
    private var config: URLSessionConfiguration = {
        let config = URLSessionConfiguration()
        return config
    }()
    
    public init(session: URLSessionProtocol = URLSession.shared,
                requestTask: URLSessionDataTaskProtocol? = nil) {
        self.session = session
        self.requestTask = requestTask
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
        
        guard ConnectionCheck.isConnectedToNetwork() else {
            completion(.failure(.noInternet))
            return
        }
        
        requestTask = session.dataTask(with: urlRequest, completionHandler: { (data, response, error) in
            if let error = error {
                print("=====> Error: \(error)")
                completion(.failure(.requestError(error)))
            }
            
            guard let data = data, let response = response as? HTTPURLResponse else {
                completion(.failure(.unknown))
                return
            }
            
            do {
                try ErrorResponseBuilder.build(from: response, error: error, data: data)

                let object = try HTTPDecodeBuilder.build(from: data, objectType: Model.self, decoder: decoder)
                
                completion(.success(object))
                PrintBuilder.prettyPrint(request: urlRequest, response: response, data: data)
            } catch {
                completion(.failure(.requestError(error)))
                PrintBuilder.prettyPrint(request: urlRequest, response: response, data: data)
            }
        })
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
        
        URLSession.shared.dataTask(
            with: request,
            completionHandler: { responseData, response, error in
                
                guard let responseData = responseData,
                      let response = response as? HTTPURLResponse else {
                    completion(.failure(.unknown))
                    return
                }
                
                do {
                    try ErrorResponseBuilder.build(from: response, error: error, data: responseData)
                    let object = try HTTPDecodeBuilder.build(from: responseData, objectType: Model.self, decoder: decoder)
                    
                    completion(.success(object))
                } catch {
                    completion(.failure(.requestError(error)))
                }
                
                PrintBuilder.prettyPrint(
                    request: request,
                    response: response,
                    data: responseData,
                    printBody: false
                )
            }).resume()
        
    }
    
    public func downloadImage(
        from urlString: String,
        completion: @escaping (Result<UIImage?, HTTPError>) -> Void
    ) {
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidImageURL))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("=====> Image download Error: \(error)")
                completion(.failure(.requestError(error)))
            }
            
            guard let imageData = data else { 
                completion(.failure(.downloadImageError))
                return
            }
            DispatchQueue.main.async {
                let image = UIImage(data: imageData)
                completion(.success(image))
            }
        }.resume()
    }
    
    public func downloadData(
        service: RequestType,
        completion: @escaping (Result<Data, HTTPError>) -> Void
    ) {
        DispatchQueue.global(qos: .background).async {
            guard let urlRequest = try? RequestBuilder.build(from: service) else {
                completion(.failure(.noData))
                return
            }
            
            guard ConnectionCheck.isConnectedToNetwork() else {
                completion(.failure(.noInternet))
                return
            }
            
            self.requestTask = self.session.dataTask(with: urlRequest, completionHandler: { (data, response, error) in
                if let error = error {
                    print("=====> Error: \(error)")
                    completion(.failure(.requestError(error)))
                }
                
                guard let data = data, let response = response as? HTTPURLResponse else {
                    completion(.failure(.unknown))
                    return
                }
                
                completion(.success(data))

            })
            self.requestTask?.resume()
        }
    }
    
    public func cancel(completion: (() -> Void)?) {
        requestTask?.cancel()
        URLSession.shared.getAllTasks { tasks in
            if tasks.count > 0 {
                _ = tasks.map { $0.cancel() }
            }
            completion?()
        }
    }
    
    public func cancel(path: String, completion: (() -> Void)?) {
        requestTask?.cancel()
        URLSession.shared.getAllTasks { tasks in
            if tasks.count > 0 {
                tasks.forEach {
                    guard let requestURL = $0.originalRequest?.url?.absoluteString else {
                        completion?() 
                        return
                    }
                    if requestURL.contains(path) == true { $0.cancel() }
                }
            }
            completion?()
        }
    }
}
