# CoreNetwork

Native Network layer Swift Package 

## Installation

- You must have permision to access Gitlab repository.

- Go to your project package Dependencies and add a new dependecy

- Search for the CoreNetwork repository: https://gitlab.usemobile.com.br/ios-team/corenetwork.git

- Add your username and the token as password.

## Usage

- To help the requests usage you should create a extension of `RequestType` and implement de commons url components for you Http request (ex: scheme, host, default headers,...).

- For authenticated request you should to provide token in `RequestType` to, therefore, if you save token in UserDefaults or another local database, when recommend the implementation in the same `RequestType` extension:

```
    extension CoreNetwork.RequestType {
        var scheme: String {
            "https"
        }
    
        var host: String {
            "api.example.com"
        }
    
        var customHeaders: [String : String] {
            [:]
        }
    
        var token: String? {
            UserDefaults.standard.string(forKey: "Authorization")
        }
    }
```  

## Authors and acknowledgment

- Filipe Teodoro

## License

- Usemobile
