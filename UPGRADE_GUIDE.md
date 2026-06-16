# Guia de Atualização — Core 2.0

> Para: desenvolvedores dos projetos que consomem a lib Core  
> Pré-requisito: ler o [MIGRATION.md](MIGRATION.md) para entender o que mudou e por quê

Este documento descreve **como executar** a atualização no seu projeto, na ordem correta, com os comandos exatos para encontrar cada ponto de mudança.

---

## Antes de começar

1. **Crie um branch dedicado** para a atualização — não misture com outras features.
2. **Garanta que os testes do seu projeto passam** na versão atual antes de atualizar. Partir de um estado verde facilita identificar o que a atualização quebrou.
3. Atualize a dependência no SPM:
   - Xcode → **File → Packages → Update to Latest Package Versions**
   - Ou edite o `Package.resolved` e aponte para a tag `2.0.0`.
4. Tente compilar. O compilador vai apontar os erros — siga os passos abaixo na ordem para corrigi-los.

---

## Passo 1 — Renomear `NewHTTPMethod` → `HTTPMethod`

**Tempo estimado:** 2 minutos  
**Impacto:** todos os arquivos de endpoint

### Como encontrar

No Xcode: **⌘⇧H** (Find & Replace no projeto inteiro)

```
Buscar:     NewHTTPMethod
Substituir: HTTPMethod
```

Ou pelo terminal na raiz do projeto:

```bash
grep -r "NewHTTPMethod" . --include="*.swift" -l
```

### O que muda

```swift
// Antes
var method: NewHTTPMethod { .post }

// Depois
var method: HTTPMethod { .post }
```

Os valores (`.get`, `.post`, `.put`, `.patch`, `.delete`) não mudam.

### Verificação

```bash
grep -r "NewHTTPMethod" . --include="*.swift"
# Deve retornar vazio
```

---

## Passo 2 — Migrar `body: [String: Any]?` para `body: Encodable?`

**Tempo estimado:** 10–30 minutos dependendo do número de endpoints  
**Impacto:** todos os endpoints com body (POST, PUT, PATCH)

### Como encontrar todos os arquivos afetados

```bash
grep -r "var body: \[String: Any\]" . --include="*.swift" -l
```

### O que muda em cada arquivo

Para cada endpoint com body, substitua o dicionário por um `struct Encodable` privado:

```swift
// Antes
enum OrderService: RequestType {
    case createOrder(productId: String, quantity: Int)

    var body: [String: Any]? {
        switch self {
        case .createOrder(let productId, let quantity):
            return ["product_id": productId, "quantity": quantity]
        }
    }
}

// Depois
enum OrderService: RequestType {
    case createOrder(productId: String, quantity: Int)

    var body: Encodable? {
        switch self {
        case .createOrder(let productId, let quantity):
            return CreateOrderBody(productId: productId, quantity: quantity)
        }
    }
}

private struct CreateOrderBody: Encodable {
    let productId: String
    let quantity: Int

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case quantity
    }
}
```

> **Sobre o `CodingKeys`:** se a API espera `snake_case` e seu projeto não configura um `JSONEncoder` com `.convertToSnakeCase`, declare as `CodingKeys` explicitamente. Se o projeto já configura o decoder com `.convertFromSnakeCase` no lado da resposta, pode precisar configurar o encoder também — veja a seção de [Configuração do JSONEncoder](#configuração-do-jsonencoder) abaixo.

**Endpoints sem body** — sem alteração necessária:

```swift
var body: Encodable? { nil }
```

### Verificação

```bash
grep -r "var body: \[String: Any\]" . --include="*.swift"
# Deve retornar vazio
```

---

## Passo 3 — Atualizar call sites de `downloadImage`

**Tempo estimado:** 5 minutos  
**Impacto:** qualquer lugar que chama `api.downloadImage`

### Como encontrar

```bash
grep -r "downloadImage" . --include="*.swift" -l
```

### O que muda

`downloadImage` agora entrega `Data` em vez de `UIImage?`. A conversão passa a ser responsabilidade do call site:

```swift
// Antes
api.downloadImage(from: urlString) { result in
    switch result {
    case .success(let image):       // UIImage?
        self.imageView.image = image
    case .failure(let error):
        self.showError(error)
    }
}

// Depois
api.downloadImage(from: urlString) { result in
    switch result {
    case .success(let data):        // Data
        self.imageView.image = UIImage(data: data)
    case .failure(let error):
        self.showError(error)
    }
}
```

**Se você usa async/await** (disponível agora na versão 2.0):

```swift
let data = try await api.downloadImage(from: urlString)
self.imageView.image = UIImage(data: data)
```

### Verificação

O compilador marca todos os locais que esperavam `UIImage?` — siga cada erro e aplique `UIImage(data:)`.

---

## Passo 4 — Atualizar mocks de `URLSessionProtocol` (se houver testes)

**Tempo estimado:** 5 minutos  
**Impacto:** targets de teste que fazem mock da URLSession

### Como encontrar

```bash
grep -r "URLSessionProtocol" . --include="*.swift" -l
```

### O que muda

`dataTask` agora retorna `URLSessionDataTaskProtocol` em vez de `URLSessionDataTask`. O mock fica mais simples — não é mais necessário herdar da classe concreta:

```swift
// Antes
class MockURLSession: URLSessionProtocol {
    func dataTask(
        with request: URLRequest,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        // precisava retornar URLSessionDataTask concreto
    }
}

// Depois
final class MockURLSession: URLSessionProtocol {
    var stubbedData: Data?
    var stubbedResponse: URLResponse?
    var stubbedError: Error?

    func dataTask(
        with request: URLRequest,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTaskProtocol {
        MockDataTask {
            completionHandler(self.stubbedData, self.stubbedResponse, self.stubbedError)
        }
    }

    func getAllTasks(completionHandler: @escaping @Sendable ([URLSessionTask]) -> Void) {
        completionHandler([])
    }
}

struct MockDataTask: URLSessionDataTaskProtocol {
    var identifier: Int = 0
    private let action: () -> Void
    init(action: @escaping () -> Void) { self.action = action }
    func resume() { action() }
    func cancel() {}
}
```

> **Novo:** o `init` de `API` agora aceita um `connectivityCheck: (() -> Bool)?`. Nos testes, passe `{ true }` para ignorar a verificação de rede:
> ```swift
> let api = API(session: mockSession, connectivityCheck: { true })
> ```

---

## Passo 5 — Revisar comportamentos que mudaram em runtime

Estes pontos **não geram erros de compilação**, mas afetam o comportamento do app. Revise cada um.

### 5.1 Mensagens de erro exibidas ao usuário

`HTTPError` agora conforma com `LocalizedError`. Qualquer lugar que exiba `error.localizedDescription` ao usuário vai mostrar as mensagens em português definidas na lib em vez da string genérica do sistema.

```bash
grep -r "localizedDescription" . --include="*.swift" -l
```

Revise cada call site e confirme que o texto em português faz sentido no contexto da tela.

### 5.2 Upload de PDF

Se o projeto faz upload de PDF com `MimeType.pdf`, o `Content-Type` agora será `application/pdf` (antes era `application/json` por bug). Confirme com o backend que não há nenhuma validação do lado do servidor que dependia do valor incorreto.

### 5.3 Observers de notificação de sessão expirada

Se o projeto observa `"SessionExpired"` ou `"ExpiredCredentials"`, os nomes continuam os mesmos — mas agora há constantes disponíveis:

```swift
// Antes
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleSessionExpired),
    name: Notification.Name("SessionExpired"),
    object: nil
)

// Depois (recomendado — mais seguro)
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleSessionExpired),
    name: .sessionExpired,
    object: nil
)
```

```bash
grep -r '"SessionExpired"\|"ExpiredCredentials"' . --include="*.swift" -l
```

### 5.4 Guards de double-callback

Se o projeto tinha algum `var didComplete = false` ou guard extra para se proteger de completions duplicadas, eles podem ser removidos — o bug de double-callback foi corrigido.

```bash
grep -r "didComplete\|didCallback\|didFinish" . --include="*.swift" -l
```

---

## Passo 6 — Compilar e rodar os testes

```bash
# Terminal
xcodebuild test -scheme NomeDoProjeto -destination 'platform=iOS Simulator,name=iPhone 16'

# Ou pelo Xcode: ⌘U
```

Todos os testes que passavam antes devem continuar passando. Se algum falhar por conta de comportamento da rede mockada, verifique se o mock implementa `getAllTasks(completionHandler:)` — esse método foi adicionado ao `URLSessionProtocol`.

---

## Oportunidades de melhoria pós-migração

Com a versão 2.0, estas melhorias ficam disponíveis. Não são obrigatórias para compilar, mas valem adotar no projeto:

### Async/await

Substitua completion handlers por async/await nos ViewModels e Services:

```swift
// Antes
func loadProfile() {
    api.request(service: UserService.profile, with: UserProfile.self) { [weak self] result in
        DispatchQueue.main.async {
            switch result {
            case .success(let profile): self?.profile = profile
            case .failure(let error): self?.errorMessage = error.localizedDescription
            }
        }
    }
}

// Depois
func loadProfile() async {
    do {
        profile = try await api.request(service: UserService.profile, with: UserProfile.self)
    } catch let error as HTTPError {
        errorMessage = error.localizedDescription
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

### Testes sem rede com injeção de conectividade

```swift
// Cria API completamente isolada do hardware de rede
let api = API(
    session: MockURLSession(data: payload, response: okResponse),
    connectivityCheck: { true }
)
```

---

## Configuração do JSONEncoder

A lib usa `JSONEncoder()` com configurações padrão (sem `.convertToSnakeCase`). Se a API do seu backend usa `snake_case` nos campos do body, declare `CodingKeys` explícitas nos seus structs de request body ou configure o `JSONDecoder` no lado da resposta separadamente do encoder do body.

---

## Checklist final

- [ ] Branch criado
- [ ] `NewHTTPMethod` → `HTTPMethod` (find & replace)
- [ ] `body: [String: Any]?` → `body: Encodable?` em todos os endpoints com body
- [ ] Call sites de `downloadImage` convertendo `Data` → `UIImage(data:)`
- [ ] Mocks de `URLSessionProtocol` atualizados (retorno + `getAllTasks`)
- [ ] `connectivityCheck: { true }` nos testes que criam `API` diretamente
- [ ] Observers de notificação usando as constantes `.sessionExpired` / `.expiredCredentials`
- [ ] Guards de double-callback removidos
- [ ] UIs que exibem `error.localizedDescription` revisadas
- [ ] Upload de PDF validado com backend
- [ ] Build limpo (zero erros, zero warnings relacionados à migração)
- [ ] Todos os testes passando
- [ ] PR aberto com link para este guia na descrição

---

## Dúvidas

Consulte o [MIGRATION.md](MIGRATION.md) para o detalhamento técnico de cada mudança ou abra uma issue no repositório da lib.
