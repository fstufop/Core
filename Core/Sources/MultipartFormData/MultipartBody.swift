import Foundation

public protocol MultipartBodyProtocol {
    func asData() -> Data
}

enum MultipartBoundary {
    static let boundary = "Boundary-\(UUID().uuidString)"
}

public enum MimeType: String {
    case pdf = "application/pdf"
    case jpeg = "image/jpeg"
    case png = "image/png"
}

public struct MultipartBody: MultipartBodyProtocol {
    private let boundary = MultipartBoundary.boundary
    private var httpBody = Data()

    public init() {}

    public func addTextField(named name: String, value: String) -> Self {
        var copy = self
        if let fieldData = textFormField(named: name, value: value).data(using: .utf8) {
            copy.httpBody.append(fieldData)
        }
        return copy
    }

    public func addDataField(named name: String, fileName: String, data: Data, mimeType: MimeType) -> Self {
        var copy = self
        copy.httpBody.append(dataFormField(named: name, fileName: fileName, data: data, mimeType: mimeType))
        return copy
    }

    private func textFormField(named name: String, value: String) -> String {
        var fieldString = "--\(boundary)\r\n"
        fieldString += "Content-Disposition: form-data; name=\"\(name)\"\r\n"
        fieldString += "Content-Type: text/plain\r\n"
        fieldString += "\r\n"
        fieldString += "\(value)\r\n"
        return fieldString
    }

    private func dataFormField(named name: String, fileName: String, data: Data, mimeType: MimeType) -> Data {
        var fieldData = Data()
        func append(_ string: String) {
            if let d = string.data(using: .utf8) { fieldData.append(d) }
        }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n")
        append("Content-Type: \(mimeType.rawValue)\r\n")
        append("\r\n")
        fieldData.append(data)
        append("\r\n")
        return fieldData
    }

    public func asData() -> Data {
        var result = httpBody
        if let terminator = "--\(boundary)--".data(using: .utf8) {
            result.append(terminator)
        }
        return result
    }
}
