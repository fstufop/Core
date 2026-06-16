# Análise Técnica — CoreNetwork

> Data: 2026-06-04  
> Versão analisada: branch `main` (commit `857eb15`)  
> Escopo: todos os 17 arquivos Swift da biblioteca

---

## Visão Geral

CoreNetwork é um Swift Package Manager (SPM) que abstrai requisições HTTP para projetos iOS. A biblioteca cobre requisições JSON padrão, upload multipart/form-data, download de imagens e dados, além de cancelamento seletivo de tasks. O design geral aposta em orientação a protocolos e no padrão Builder, o que é adequado para o contexto.

---

## O que está bom

### Design orientado a protocolos
`HTTPProtocol`, `RequestType`, `URLSessionProtocol` e `URLSessionDataTaskProtocol` formam contratos claros que permitem substituição em testes e extensão sem modificar a biblioteca.

### Injeção de dependência via protocolo
`API.init(session:)` aceita qualquer `URLSessionProtocol`, o que é a base correta para um networking layer testável.

### Padrão Builder bem delimitado
Cada Builder tem responsabilidade única: `RequestBuilder` monta a `URLRequest`, `HeaderBuilder` cuida de headers, `ErrorResponseBuilder` valida status codes e `HTTPDecodeBuilder` faz parse. Boa separação de concerns.

### `Result<T, HTTPError>` em todas as completions
Retorno tipado com erro de domínio próprio é mais expressivo que o padrão `(T?, Error?)` ainda comum em codebases legados.

### `MultipartBody` com method chaining
Interface fluente (`addTextField().addDataField()`) facilita a construção do corpo sem boilerplate.

### `ErrorResponseBuilder` centraliza lógica de status HTTP
Em vez de cada consumidor interpretar o status code, a validação fica em um único lugar.

---

## Bugs e problemas

### Críticos

#### 1. `multipartRequest` e `downloadImage` ignoram a sessão injetada
**Arquivos:** `API.swift` linhas 73 e 111

```swift
// multipartRequest — linha 73
URLSession.shared.dataTask(with: request, ...) // deveria ser self.session

// downloadImage — linha 111
URLSession.shared.dataTask(with: url) { ... } // deveria ser self.session
```

A DI existe no `init`, mas dois dos quatro métodos públicos ignoram a sessão injetada e usam `URLSession.shared` diretamente. Isso torna esses métodos **impossíveis de testar em isolamento** e inconsistentes com o método `request()`.

---

#### 2. MIME type incorreto para PDF
**Arquivo:** `MultipartBody.swift` linha 12

```swift
public enum MimeType: String {
    case pdf = "application/json"  // ERRADO — deveria ser "application/pdf"
    case jpeg = "image/jpeg"
    case png = "image/png"
}
```

Upload de PDF envia o header `Content-Type: application/json`, o que vai causar rejeição ou comportamento inesperado no servidor.

---

#### 3. Double completion call — completion é chamado duas vezes em caso de erro
**Arquivo:** `API.swift` linhas 35–42 e `downloadData()` linhas 143–149

```swift
requestTask = session.dataTask(with: urlRequest) { (data, response, error) in
    if let error = error {
        completion(.failure(.requestError(error)))
        // FALTA return aqui
    }
    // Se error != nil, data e response serão nil
    // Então o guard abaixo também chama completion:
    guard let data = data, let response = response as? HTTPURLResponse else {
        completion(.failure(.unknown))
        return
    }
}
```

Quando a URLSession retorna um erro, `completion` é chamado com `.requestError`, mas sem `return`, a execução continua e o `guard` chama `completion` novamente com `.unknown`. Dois callbacks para a mesma requisição.

---

#### 4. Custom headers do `MultipartFormDataRequest` são silenciosamente ignorados
**Arquivo:** `MultipartFormDataRequest.swift` linhas 25–27

```swift
request.allHTTPHeaderFields?.merge(service.customHeaders) { current, _ in current }
```

`allHTTPHeaderFields` retorna uma **cópia** opcional do dicionário. O `merge` acontece nessa cópia temporária e nunca é atribuído de volta a `request`. Custom headers de requisições multipart são descartados sem nenhum erro.

---

#### 5. `cancel(path:)` usa `URLSession.shared` em vez da sessão injetada
**Arquivo:** `API.swift` linhas 163 e 172

Mesmo problema do item 1 — quebra a abstração e não funciona com mocks.

---

### Moderados

#### 6. `ConnectionCheck` usa API obsoleta e tem force unwrap
**Arquivo:** `ConnectionCheck.swift` linha 16

```swift
if SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) == false {
```

`SCNetworkReachability` com `kSCNetworkFlagsReachable` é considerada **não confiável** desde iOS 12 — pode retornar `true` mesmo sem internet real. A alternativa moderna é `NWPathMonitor` (framework `Network`). O force-unwrap em `defaultRouteReachability!` é um crash em potencial.

---

#### 7. `PrintBuilder` ativo em produção sem flag de compilação
**Arquivo:** `PrintBuilder.swift`

Toda requisição imprime URL, headers, token de autenticação e corpo da resposta no console sem nenhuma guarda `#if DEBUG`. Em produção isso expõe dados sensíveis e degrada performance.

---

#### 8. `requestTask` não é thread-safe
**Arquivo:** `API.swift` linhas 4, 34, 143, 157

`requestTask` é uma propriedade de instância escrita de dentro de closures de completion que rodam em threads da URLSession. Duas chamadas concorrentes a `request()` geram data race. Também, como `requestTask` guarda apenas **uma** referência, chamadas concorrentes sobrescrevem a referência anterior, e `cancel()` só afeta a última task criada.

---

#### 9. `MultipartBody.asData()` tem side effect destrutivo
**Arquivo:** `MultipartBody.swift` linhas 61–64

```swift
public func asData() -> Data {
    httpBody.appendString("--\(boundary)--")  // modifica o estado interno
    return httpBody as Data
}
```

`httpBody` é `NSMutableData` (referência). Chamar `asData()` duas vezes appenda `--boundary--` duas vezes, corrompendo o payload. Como `MultipartBody` é uma `struct` com semântica de valor, o ideal seria que `asData()` fosse puro (não mutasse o estado).

---

#### 10. `ErrorResponseBuilder` descarta o erro original
**Arquivo:** `ErrorResponseBuilder.swift` linhas 4–7

```swift
guard error == nil else {
    throw HTTPError.unknown  // erro real é perdido
}
```

O `Error` recebido pela URLSession contém informação diagnóstica (timeout, host unreachable, SSL failure, etc.) que é completamente descartada. Deveria ser propagado como `.requestError(error)`.

---

#### 11. `downloadData` usa `DispatchQueue.global` desnecessariamente
**Arquivo:** `API.swift` linhas 132–158

```swift
public func downloadData(service:...) {
    DispatchQueue.global(qos: .background).async {
```

`URLSession` já executa tasks em threads de background. O `DispatchQueue.global` extra não adiciona nada e cria um closure capturando `self` fortemente de forma desnecessária.

---

### Menores / Dívida Técnica

#### 12. Sem async/await
A API é baseada inteiramente em completion handlers. Swift 5.5 (iOS 15+) introduziu async/await e o modelo de concorrência estruturada. Uma camada de networking nova em 2024+ deveria oferecer ao menos uma interface async.

---

#### 13. `URLSessionProtocol` retorna o tipo concreto `URLSessionDataTask`
**Arquivo:** `URLSessionProtocol.swift` linha 5

```swift
func dataTask(with:completionHandler:) -> URLSessionDataTask  // deveria ser URLSessionDataTaskProtocol
```

O protocolo de abstração quebra sua própria abstração ao retornar o tipo concreto. Mocks precisam implementar o protocolo mas devolver um `URLSessionDataTask` concreto, o que é contraditório.

---

#### 14. `HTTPProtocol` e `API.swift` importam UIKit
**Arquivos:** `HTTPProtocol.swift` e `API.swift` linha 1

Um protocolo de networking não deveria depender de UIKit. Isso impede o uso da biblioteca em extensões, targets de serviço, e qualquer contexto não-UIKit. `UIImage` poderia ser substituído por `Data` na interface pública, com a conversão ficando a cargo do chamador.

---

#### 15. `HTTPError` não conforma com `LocalizedError`
**Arquivo:** `HTTPError.swift`

```swift
public enum HTTPError: Error {
    var localizedDescription: String { ... }  // propriedade normal, não o protocolo
```

`Error.localizedDescription` usa `LocalizedError.errorDescription` para exibição. Como `HTTPError` não conforma com `LocalizedError`, as mensagens em português nunca são exibidas pelo sistema — `error.localizedDescription` retorna a string genérica de `NSError`.

---

#### 16. `RequestBuilder` usa `.prettyPrinted` ao serializar o body
**Arquivo:** `RequestBuilder.swift` linha 31

```swift
let encoder = try JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
```

`.prettyPrinted` adiciona espaços e quebras de linha ao JSON enviado ao servidor. Não causa falha (servidores ignoram whitespace), mas aumenta o tamanho do payload sem motivo.

---

#### 17. `RequestType.body: [String: Any]?` perde type safety
**Arquivo:** `RequestType.swift` linha 11

Usar `[String: Any]` em vez de `Encodable` significa que erros de serialização só aparecem em runtime. Modelar o body como `Encodable` (ou `Data`) propagaria erros em tempo de compilação.

---

#### 18. Nome `NewHTTPMethod` é code smell
**Arquivo:** `HTTPMethod.swift` linha 3

O prefixo "New" sugere que existe (ou existiu) um `HTTPMethod` antigo em algum lugar. Renomear para `HTTPMethod` diretamente.

---

#### 19. Arquivo com typo no nome
`URLSessionDataTeskProtocol.swift` — "Tesk" em vez de "Task".

---

#### 20. Testes ausentes
**Arquivo:** `CoreTests.swift`

O único método de teste é um placeholder vazio. Uma biblioteca de networking sem testes impede refatorações seguras. Os protocolos de URLSession foram criados exatamente para viabilizar testes com mocks, mas nunca foram usados para isso.

---

#### 21. Notification names como string literal
**Arquivo:** `ErrorResponseBuilder.swift` linhas 15, 18

```swift
NotificationCenter.default.post(name: Notification.Name("SessionExpired"), ...)
NotificationCenter.default.post(name: Notification.Name("ExpiredCredentials"), ...)
```

Strings literais são frágeis — um typo em qualquer observer passa em silêncio. O padrão Swift é declarar `static let` em uma extensão de `Notification.Name`.

---

#### 22. README com erros de ortografia e informação sensível
O README expõe a URL interna do GitLab (`gitlab.usemobile.com.br`) e contém "permision" e "dependecy" com erros de digitação.

---

## Resumo por severidade

| Severidade | Quantidade | Exemplos |
|---|---|---|
| **Crítico** (bug real) | 5 | Double completion, MIME errado, DI ignorada, headers descartados |
| **Moderado** (comportamento incorreto) | 6 | API obsoleta, prints em produção, race condition, side effect destrutivo |
| **Menor / Debt** | 11 | Sem async/await, import UIKit, sem testes, typos |

---

## Recomendações prioritárias

1. **Fix imediato:** Substituir `URLSession.shared` por `self.session` em `multipartRequest` e `downloadImage`.
2. **Fix imediato:** Adicionar `return` após cada chamada de `completion(.failure(...))` nos data task closures.
3. **Fix imediato:** Corrigir `MimeType.pdf = "application/pdf"`.
4. **Fix imediato:** Atribuir o resultado do merge de headers de volta em `MultipartFormDataRequest.build()`.
5. **Curto prazo:** Adicionar `#if DEBUG` em `PrintBuilder`.
6. **Curto prazo:** Substituir `ConnectionCheck` por `NWPathMonitor`.
7. **Curto prazo:** Fazer `HTTPError` conformar com `LocalizedError`.
8. **Médio prazo:** Adicionar testes unitários usando os mocks que os protocolos já permitem.
9. **Médio prazo:** Expor uma API async/await paralela às completions existentes.
10. **Médio prazo:** Remover dependência de UIKit dos protocolos públicos.
