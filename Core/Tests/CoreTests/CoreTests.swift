import XCTest
@testable import Core

final class CoreTests: XCTestCase {

    // MARK: - MimeType

    func testMimeTypePDFValue() {
        XCTAssertEqual(MimeType.pdf.rawValue, "application/pdf")
    }

    func testMimeTypeJPEGValue() {
        XCTAssertEqual(MimeType.jpeg.rawValue, "image/jpeg")
    }

    func testMimeTypePNGValue() {
        XCTAssertEqual(MimeType.png.rawValue, "image/png")
    }

    // MARK: - HTTPMethod

    func testHTTPMethodRawValues() {
        XCTAssertEqual(HTTPMethod.get.rawValue, "GET")
        XCTAssertEqual(HTTPMethod.post.rawValue, "POST")
        XCTAssertEqual(HTTPMethod.put.rawValue, "PUT")
        XCTAssertEqual(HTTPMethod.patch.rawValue, "PATCH")
        XCTAssertEqual(HTTPMethod.delete.rawValue, "DELETE")
    }

    // MARK: - HTTPError LocalizedError

    func testHTTPErrorUsesLocalizedErrorDescription() {
        let errors: [(HTTPError, String)] = [
            (.noInternet, "Estamos tendo problemas com a conexão."),
            (.unauthorized, "Autenticação inválida"),
            (.invalidImageURL, "A URL da imagem é inválida."),
            (.serverError(500), "Estamos em manutenção para melhor atende-lo."),
            (.parseFailed, "Erro ao montar sua solicitação.")
        ]
        for (error, expected) in errors {
            XCTAssertEqual(error.localizedDescription, expected, "HTTPError.\(error)")
        }
    }

    // MARK: - MultipartBody

    func testAsDataIsIdempotent() {
        let body = MultipartBody()
            .addTextField(named: "key", value: "value")

        let first = body.asData()
        let second = body.asData()

        XCTAssertEqual(first, second, "asData() deve retornar o mesmo resultado em chamadas repetidas")
    }

    func testAsDataContainsBoundaryTerminator() {
        let data = MultipartBody().asData()
        let text = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(text.hasSuffix("--"), "payload deve terminar com o terminator do boundary")
    }

    func testAddTextFieldDoesNotMutateOriginal() {
        let original = MultipartBody()
        let withField = original.addTextField(named: "x", value: "1")
        XCTAssertNotEqual(original.asData(), withField.asData(), "addTextField deve retornar nova instância")
    }

    // MARK: - API — completion chamado uma única vez em erro

    func testRequestCompletionCalledOnceOnNetworkError() {
        let expectation = expectation(description: "completion chamado exatamente uma vez")
        expectation.expectedFulfillmentCount = 1
        expectation.assertForOverFulfill = true

        let session = MockURLSession(error: URLError(.notConnectedToInternet))
        let api = API(session: session, connectivityCheck: { true })

        api.request(service: MockService(), with: EmptyResponse.self) { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testRequestReturnsRequestErrorOnNetworkFailure() {
        let networkError = URLError(.timedOut)
        let expectation = expectation(description: "recebe requestError")

        let session = MockURLSession(error: networkError)
        let api = API(session: session, connectivityCheck: { true })

        api.request(service: MockService(), with: EmptyResponse.self) { result in
            if case .failure(let httpError) = result,
               case .requestError(let underlying) = httpError {
                XCTAssertEqual((underlying as? URLError)?.code, .timedOut)
            } else {
                XCTFail("Esperado .requestError, recebido \(result)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testRequestDecodesSuccessResponse() throws {
        let payload = try JSONEncoder().encode(MockUser(name: "Alice"))
        let response = HTTPURLResponse(url: URL(string: "https://api.test")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let session = MockURLSession(data: payload, response: response)
        let api = API(session: session, connectivityCheck: { true })

        let expectation = expectation(description: "decodifica resposta")
        api.request(service: MockService(), with: MockUser.self) { result in
            if case .success(let user) = result {
                XCTAssertEqual(user.name, "Alice")
            } else {
                XCTFail("Esperado sucesso, recebido \(result)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - URLSessionProtocol — mock funciona sem URLSessionDataTask concreto

    func testMockSessionConformsToProtocol() {
        let session: URLSessionProtocol = MockURLSession()
        let task = session.dataTask(with: URLRequest(url: URL(string: "https://test")!)) { _, _, _ in }
        XCTAssertNotNil(task)
    }
}

// MARK: - Helpers

private struct MockService: RequestType {
    var scheme: String { "https" }
    var host: String { "api.example.com" }
    var path: String { "/test" }
    var port: Int? { nil }
    var method: HTTPMethod { .get }
    var customHeaders: [String: String] { [:] }
    var body: Encodable? { nil }
    var queryParams: [String: String]? { nil }
    var token: String? { nil }
}

private struct EmptyResponse: Decodable {}
private struct MockUser: Codable { let name: String }

private final class MockURLSession: URLSessionProtocol {
    private let error: Error?
    private let data: Data?
    private let response: URLResponse?

    init(error: Error? = nil, data: Data? = nil, response: URLResponse? = nil) {
        self.error = error
        self.data = data
        self.response = response
    }

    func dataTask(
        with request: URLRequest,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTaskProtocol {
        MockDataTask { [weak self] in
            completionHandler(self?.data, self?.response, self?.error)
        }
    }

    func getAllTasks(completionHandler: @escaping @Sendable ([URLSessionTask]) -> Void) {
        completionHandler([])
    }
}

private struct MockDataTask: URLSessionDataTaskProtocol {
    var identifier: Int = 0
    private let action: () -> Void
    init(action: @escaping () -> Void) { self.action = action }
    func resume() { action() }
    func cancel() {}
}
