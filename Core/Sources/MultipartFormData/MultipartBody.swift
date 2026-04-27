import Foundation

public protocol MultipartBodyProtocol {
    func asData() -> Data
}

enum MultipartBoundary {
    static let boundary = "Boundary-\(UUID().uuidString)"
}

public enum MimeType: String {
    case pdf = "application/json"
    case jpeg = "image/jpeg"
    case png = "image/png"
}

public struct MultipartBody: MultipartBodyProtocol {
    private let boundary = MultipartBoundary.boundary
    private var httpBody = NSMutableData()
    
    public init() {}

    public func addTextField(named name: String, value: String) -> Self {
        httpBody.appendString(textFormField(named: name, value: value))
        return self
    }

    public func addDataField(named name: String, fileName: String, data: Data, mimeType: MimeType) -> Self {
        httpBody.append(dataFormField(named: name, fileName: fileName, data: data, mimeType: mimeType))
        return self
    }

    private func textFormField(named name: String, value: String) -> String {
        var fieldString = "--\(boundary)\r\n"
        fieldString += "Content-Disposition: form-data; name=\"\(name)\"\r\n"
        fieldString += "Content-Type: text/plain\r\n"
        fieldString += "\r\n"
        fieldString += "\(value)\r\n"
        
        return fieldString
    }

    private func dataFormField(
        named name: String,
        fileName: String,
        data: Data,
        mimeType: MimeType
    ) -> Data {
        let fieldData = NSMutableData()

        fieldData.appendString("--\(boundary)\r\n")
        fieldData.appendString("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n")
        fieldData.appendString("Content-Type: \(mimeType.rawValue)\r\n")
        fieldData.appendString("\r\n")
        fieldData.append(data)
        fieldData.appendString("\r\n")

        return fieldData as Data
    }

    public func asData() -> Data {
        httpBody.appendString("--\(boundary)--")
        return httpBody as Data
    }
}
