# Migration Guide — Core 1.x → 2.0

> Data: 2026-06-08  
> Versão anterior: 1.x  
> Versão nova: 2.0

Esta versão contém correções de bugs críticos e melhorias de consistência. Quatro mudanças são **breaking changes** — a maioria requer apenas find & replace no seu projeto.

---

## Índice

1. [Renomeação: `NewHTTPMethod` → `HTTPMethod`](#1-renomeação-newhttpmethod--httpmethod)
2. [`RequestType.body` muda de `[String: Any]?` para `Encodable?`](#2-requesttypebody-muda-de-string-any-para-encodable)
3. [`downloadImage` passa a retornar `Data` em vez de `UIImage?`](#3-downloadimage-passa-a-retornar-data-em-vez-de-uiimage)
4. [Mock de `URLSessionProtocol` (para testes)](#4-mock-de-urlsessionprotocol-para-testes)
5. [Mudanças de comportamento (sem quebra de compilação)](#5-mudanças-de-comportamento-sem-quebra-de-compilação)

---

## 1. Renomeação: `NewHTTPMethod` → `HTTPMethod`

**Impacto:** 100% dos consumidores — qualquer endpoint que implementa `RequestType` usa este tipo.

O prefixo "New" era um code smell de migração incompleta. O tipo foi renomeado para `HTTPMethod`.

### Antes

```swift
// Enum de endpoint
enum UserService: RequestType {
    var method: NewHTTPMethod { .get }
}
```

### Depois

```swift
enum UserService: RequestType {
    var method: HTTPMethod { .get }
}
```

**Estratégia de migração:** No Xcode, use **Find & Replace** (⌘⇧H) em todo o projeto:

- Buscar: `NewHTTPMethod`
- Substituir por: `HTTPMethod`

> Nenhuma mudança nos valores `.get`, `.post`, `.put`, `.patch`, `.delete` — apenas o nome do tipo muda.

---

## 2. `RequestType.body` muda de `[String: Any]?` para `Encodable?`

**Impacto:** 100% dos consumidores que têm endpoints com body (POST, PUT, PATCH).

A mudança elimina erros de serialização em runtime — o compilador agora garante que o body é serializável.

### Antes

```swift
enum UserService: RequestType {
    case updateProfile(name: String, age: Int)

    var body: [String: Any]? {
        switch self {
        case .updateProfile(let name, let age):
            return ["name": name, "age": age]
        }
    }
}
```

### Depois

Crie um `struct` ou `Encodable` para representar o body:

```swift
enum UserService: RequestType {
    case updateProfile(name: String, age: Int)

    var body: Encodable? {
        switch self {
        case .updateProfile(let name, let age):
            return UpdateProfileBody(name: name, age: age)
        }
    }
}

private struct UpdateProfileBody: Encodable {
    let name: String
    let age: Int
}
```

**Endpoints sem body:** Nenhuma alteração necessária — `nil` continua válido.

```swift
var body: Encodable? { nil }  // mesmo que antes
```

**Dica:** Se o body é um dicionário simples com valores heterogêneos (`[String: Any]`) e você não quer criar um struct agora, pode usar `AnyCodable` ou serializar para `Data` diretamente — mas o `struct Encodable` é o caminho recomendado.

---

## 3. `downloadImage` passa a retornar `Data` em vez de `UIImage?`

**Impacto:** Consumidores que utilizam `API.downloadImage(from:completion:)`.

A dependência de `UIKit` foi removida da lib para permitir uso em extensões, widgets e targets de serviço. A conversão para `UIImage` agora é responsabilidade do call site.

### Antes

```swift
api.downloadImage(from: urlString) { result in
    switch result {
    case .success(let image):
        imageView.image = image  // UIImage? direto
    case .failure(let error):
        print(error)
    }
}
```

### Depois

```swift
api.downloadImage(from: urlString) { result in
    switch result {
    case .success(let data):
        imageView.image = UIImage(data: data)  // conversão no call site
    case .failure(let error):
        print(error)
    }
}
```

**Caso com `data` nulo:** O retorno anterior era `UIImage?` (opcional). O novo retorno é `Data` (não opcional) — se não houver dados, o resultado é `.failure(.noData)`. O `guard` no call site pode ser removido.

---

## 4. Mock de `URLSessionProtocol` (para testes)

**Impacto:** Times que implementam um mock de `URLSessionProtocol` para testes unitários.

O método `dataTask` agora retorna `URLSessionDataTaskProtocol` em vez de `URLSessionDataTask` concreto, tornando o protocolo autocontido.

### Antes

```swift
class MockURLSession: URLSessionProtocol {
    func dataTask(
        with request: URLRequest,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {  // tipo concreto
        let task = MockDataTask()
        // ...
        return task  // MockDataTask precisava herdar de URLSessionDataTask
    }
}
```

### Depois

```swift
class MockURLSession: URLSessionProtocol {
    func dataTask(
        with request: URLRequest,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTaskProtocol {  // protocolo
        return MockDataTask()  // struct/class que implementa URLSessionDataTaskProtocol
    }
}

struct MockDataTask: URLSessionDataTaskProtocol {
    var identifier: Int = 0
    func resume() {}
    func cancel() {}
}
```

> Esta mudança, na prática, **simplifica** os mocks — não é mais necessário herdar de `URLSessionDataTask`.

---

## 5. Mudanças de comportamento (sem quebra de compilação)

Estas correções não alteram assinaturas de método, mas mudam o comportamento em runtime. Revise se alguma afeta seu app.

### 5.1 Upload de PDF agora envia `Content-Type: application/pdf`

`MimeType.pdf` estava com o valor errado (`"application/json"`). Agora está correto (`"application/pdf"`).

**Ação necessária:** Se o servidor tinha algum tratamento especial para receber PDFs como `application/json`, esse workaround pode ser removido. Se não havia workaround, o upload de PDF passa a funcionar corretamente.

### 5.2 Completion handler chamado apenas uma vez em caso de erro

Em versões anteriores, um erro de rede disparava o completion duas vezes (`.requestError` seguido de `.unknown`). Agora é chamado uma única vez.

**Ação necessária:** Remova qualquer guard ou flag `var didComplete = false` que tenha sido adicionado para defender contra double-callback.

### 5.3 Custom headers em `multipartRequest` agora chegam ao servidor

`customHeaders` definidos no `RequestType` eram silenciosamente ignorados em chamadas multipart. Agora são enviados corretamente.

**Ação necessária:** Se você adicionava headers de autenticação via `customHeaders` em endpoints multipart e eles não funcionavam, agora vão funcionar — sem nenhuma alteração de código.

### 5.4 `error.localizedDescription` retorna mensagens em português

`HTTPError` agora conforma com `LocalizedError`. Antes, `error.localizedDescription` retornava a string genérica do sistema (`"The operation couldn't be completed."`). Agora retorna as mensagens definidas na lib.

**Ação necessária:** Revise UIs que exibem `error.localizedDescription` — o texto exibido ao usuário vai mudar.

### 5.5 Sessão injetada respeitada em `multipartRequest`, `downloadImage` e `cancel(path:)`

Esses três métodos usavam `URLSession.shared` internamente, ignorando a sessão injetada no `init`. Agora usam `self.session`.

**Ação necessária:** Se você injetava uma sessão customizada (ex.: com configuração de timeout ou certificado) e percebia que não tinha efeito nesses métodos, agora terá. Nenhuma alteração de código necessária.

---

## Checklist de migração

- [ ] Find & Replace: `NewHTTPMethod` → `HTTPMethod` em todo o projeto
- [ ] Atualizar `var body` em todos os enums/structs que implementam `RequestType` para retornar `Encodable?`
- [ ] Atualizar call sites de `downloadImage` para converter `Data` → `UIImage(data:)`
- [ ] Atualizar mocks de `URLSessionProtocol` para retornar `URLSessionDataTaskProtocol`
- [ ] Revisar UIs que exibem `error.localizedDescription`
- [ ] Remover workarounds de double-callback em completion handlers
- [ ] Verificar integração de upload de PDF com o backend

---

## Dúvidas

Abra uma issue no repositório ou entre em contato com o time de plataforma.
