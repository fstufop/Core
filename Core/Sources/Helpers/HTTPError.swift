import Foundation

public enum HTTPError: Error, LocalizedError {
    case downloadImageError
    case expiredCredentials
    case noData
    case invalidURL
    case invalidCredentials
    case invalidImageURL
    case noInternet
    case parseFailed
    case statusCode(_ statusCode: Int, _ object: Any)
    case unknown
    case unauthorized
    case serverError(_ statusCode: Int)
    case requestFormDataError
    case requestError(_ error: Error)

    public var errorDescription: String? {
        switch self {
        case .downloadImageError:
            return "Error ao baixar a imagem."
        case .noData, .invalidURL, .unknown, .statusCode, .requestError, .requestFormDataError:
            return "Não conseguimos realizar a sua solicitação."
        case .invalidImageURL:
            return "A URL da imagem é inválida."
        case .serverError:
            return "Estamos em manutenção para melhor atende-lo."
        case .parseFailed:
            return "Erro ao montar sua solicitação."
        case .noInternet:
            return "Estamos tendo problemas com a conexão."
        case .invalidCredentials:
            return "Credenciais inválidas"
        case .expiredCredentials:
            return "Credenciais expiradas"
        case .unauthorized:
            return "Autenticação inválida"
        }
    }
}
