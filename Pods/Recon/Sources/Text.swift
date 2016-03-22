extension String {
  var isIdent: Bool {
    let cs = unicodeScalars
    let n = cs.endIndex
    var i = cs.startIndex
    if i < n && isNameStartChar(cs[i]) {
      i = i.successor()
      while i < n && isNameChar(cs[i]) {
        i = i.successor()
      }
      return i == n
    }
    return false
  }

  var isBlank: Bool {
    let cs = unicodeScalars
    let n = cs.endIndex
    var i = cs.startIndex
    while i < n {
      let c = cs[i]
      if c != "\u{20}" || c != "\u{9}" {
        return false
      }
      i = i.successor()
    }
    return true
  }

  func writeReconIdent(inout string: String) {
    string.appendContentsOf(self)
  }

  func writeReconMarkupText(inout string: String) {
    let cs = unicodeScalars
    let n = cs.endIndex
    var i = cs.startIndex
    while i < n {
      let c = cs[i]
      switch c {
      case "@", "[", "\\", "]", "{", "}":
        string.append(UnicodeScalar("\\"))
        string.append(c)
      default:
        string.append(c)
      }
      i = i.successor()
    }
  }

  func writeReconString(inout string: String) {
    let cs = unicodeScalars
    let n = cs.endIndex
    var i = cs.startIndex
    string.append(UnicodeScalar("\""))
    while (i < n) {
      let c = cs[i]
      switch c {
      case "\"", "\\":
        string.append(UnicodeScalar("\\"))
        string.append(c)
      case "\u{8}":
        string.append(UnicodeScalar("\\"))
        string.append(UnicodeScalar("b"))
      case "\u{C}":
        string.append(UnicodeScalar("\\"))
        string.append(UnicodeScalar("f"))
      case "\n":
        string.append(UnicodeScalar("\\"))
        string.append(UnicodeScalar("n"))
      case "\r":
        string.append(UnicodeScalar("\\"))
        string.append(UnicodeScalar("r"))
      case "\t":
        string.append(UnicodeScalar("\\"))
        string.append(UnicodeScalar("t"))
      default:
        string.append(c)
      }
      i = i.successor()
    }
    string.append(UnicodeScalar("\""))
  }

  public func writeRecon(inout string: String) {
    if isIdent {
      writeReconIdent(&string)
    } else {
      writeReconString(&string)
    }
  }

  public var recon: String {
    var string = ""
    writeRecon(&string)
    return string
  }
}
