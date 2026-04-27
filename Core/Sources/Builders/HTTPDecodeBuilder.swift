import Foundation

struct HTTPDecodeBuilder {
    static func build<Model: Decodable>(
        from data: Data?,
        objectType: Model.Type?,
        decoder: JSONDecoder
    ) throws -> Model {
        
        guard let objectType = objectType else { throw HTTPError.unknown }
        guard let data = data else { throw HTTPError.noData }
        do {
            let object = try decoder.decode(objectType, from: data)
            return object
        } catch {
            debugPrint("===> Decode ERROR: ", error.localizedDescription)
            throw HTTPError.parseFailed
        }
    }

    static func buildToDictionary(from data: Data?) throws -> Any {
        guard let data = data else { throw HTTPError.noData }
        do {
            let json = try JSONSerialization.jsonObject(
                with: data,
                options: .mutableContainers
            )
            return json
        } catch {
            debugPrint(error)
            throw HTTPError.parseFailed
        }
    }
}
