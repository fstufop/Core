# CoreNetwork

Native networking layer as a Swift Package for iOS projects.

## Installation

Add the package via **File → Add Package Dependencies** in Xcode and enter the repository URL. When prompted, provide your username and a personal access token as the password.

## Usage

### 1. Configure a base `RequestType` extension

Create an extension that provides shared URL components for all your endpoints:

```swift
extension RequestType {
    var scheme: String { "https" }
    var host: String { "api.example.com" }
    var port: Int? { nil }
    var customHeaders: [String: String] { [:] }

    var token: String? {
        UserDefaults.standard.string(forKey: "Authorization")
    }
}
```

### 2. Define endpoints

```swift
enum UserService: RequestType {
    case getProfile
    case updateProfile(name: String)

    var path: String {
        switch self {
        case .getProfile, .updateProfile: return "/users/me"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .getProfile: return .get
        case .updateProfile: return .put
        }
    }

    var body: Encodable? {
        switch self {
        case .getProfile: return nil
        case .updateProfile(let name): return UpdateBody(name: name)
        }
    }

    var queryParams: [String: String]? { nil }
}

private struct UpdateBody: Encodable {
    let name: String
}
```

### 3. Make requests

**Completion handler:**

```swift
let api = API()

api.request(service: UserService.getProfile, with: UserProfile.self) { result in
    switch result {
    case .success(let profile): print(profile)
    case .failure(let error): print(error.localizedDescription)
    }
}
```

**Async/await (iOS 13+):**

```swift
let profile = try await api.request(service: UserService.getProfile, with: UserProfile.self)
```

### 4. Multipart uploads

```swift
let body = MultipartBody()
    .addTextField(named: "description", value: "Profile photo")
    .addDataField(named: "file", fileName: "photo.jpg", data: imageData, mimeType: .jpeg)

api.multipartRequest(service: UploadService.photo, with: UploadResponse.self, body: body) { result in
    // handle result
}
```

### 5. Image and data downloads

```swift
// Returns Data — convert to UIImage at the call site
api.downloadImage(from: "https://api.example.com/avatar.jpg") { result in
    if case .success(let data) = result {
        imageView.image = UIImage(data: data)
    }
}

api.downloadData(service: FileService.pdf) { result in
    // handle Data
}
```

### 6. Cancellation

```swift
// Cancel the current tracked task
api.cancel(completion: nil)

// Cancel all tasks whose URL contains a path segment
api.cancel(path: "/uploads", completion: nil)
```

### 7. Dependency injection / testing

`API` accepts a custom `URLSessionProtocol` and a connectivity check closure, making it fully testable without hitting the network:

```swift
let api = API(session: mockSession, connectivityCheck: { true })
```

## Notifications

The library posts the following notifications on authentication errors:

| Notification | Trigger |
|---|---|
| `Notification.Name.sessionExpired` | HTTP 401 |
| `Notification.Name.expiredCredentials` | HTTP 403 |

## Authors

- Filipe Teodoro

## License

Usemobile
