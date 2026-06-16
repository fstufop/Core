import Foundation

final class PrintBuilder {
    static func prettyPrint(
        request: URLRequest,
        response: HTTPURLResponse?,
        data: Data?,
        printBody: Bool = true
    ) {
        #if DEBUG
        debugPrint("===================== REQUEST =====================")
        debugPrint("===> URL: \(request.url?.absoluteString ?? "")")
        debugPrint("===> METHOD: \(request.httpMethod ?? "")")
        debugPrint("===> HEADERS: \(String(describing: request.allHTTPHeaderFields ?? [:]))")

        if printBody,
           let bodyData = request.httpBody,
           let requestBody = String(data: bodyData, encoding: .utf8) {
            debugPrint("===> Requested BODY: \(requestBody)")
        }

        if let response = response {
            debugPrint("=========> STATUSCODE: \(response.statusCode)")
        }

        guard let data = data else {
            debugPrint("===========> NO DATA!")
            return
        }
        debugPrint("===> RESPONSE")
        debugPrint(String(data: data, encoding: .utf8) ?? "")
        debugPrint("====================================================")
        #endif
    }
}
