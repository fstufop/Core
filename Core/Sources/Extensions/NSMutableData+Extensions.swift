import Foundation

extension NSMutableData {
  func appendString(_ string: String) {
      if let data = string.data(using: String.Encoding.utf8) {
      self.append(data)
    }
      else {
          print("===> ERRO NA ENCODIFICACAO DA STRING")
      }
  }
}
