import Foundation

struct ErrorResponseBuilder {
    static func build(from response: HTTPURLResponse, error: Error?, data: Data? = nil) throws {
        guard error == nil else {
            throw HTTPError.unknown
        }

        let statusCode = response.statusCode
        
        switch statusCode {
        case 200...299:
            return
        case 401:
            NotificationCenter.default.post(name: Notification.Name("SessionExpired"), object: nil)
            throw HTTPError.unauthorized
        case 422:
            throw HTTPError.invalidCredentials
        case 500...504:
            throw HTTPError.serverError(statusCode)
        default:
            if let data = data, let errorObject = try? HTTPDecodeBuilder.buildToDictionary(from: data) {
                throw HTTPError.statusCode(statusCode, errorObject)
            } else {
                throw HTTPError.unknown
            }
        }
    }
}
