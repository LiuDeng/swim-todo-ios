struct UriParser: Iteratee {
  func feed(input: IterateeInput) -> IterateeOutput {
    if !input.isEmpty {
      var look = input
      while let c = look.head where isSchemeChar(c) {
        look = look.tail
      }
      if let c = look.head where c == ":" {
        return UriRestSchemeParser().feed(input)
      } else {
        return UriRestAuthorityPathQueryFragmentParser().feed(input)
      }
    } else if input.isDone {
      return done(Uri.Empty, input)
    }
    return cont(self, input)
  }
}

private struct UriRestSchemeParser: Iteratee {
  private let scheme: Iteratee

  private init(_ scheme: Iteratee = UriSchemeParser()) {
    self.scheme = scheme
  }

  private func feed(input: IterateeInput) -> IterateeOutput {
    var output = cont(scheme, input)
    while case IterateeOutput.Cont(let next, let remaining) = output where !remaining.isEmpty || remaining.isDone {
      output = next.feed(remaining)
    }
    switch output {
    case IterateeOutput.Cont(let next, let remaining):
      return cont(UriRestSchemeParser(next), remaining)
    case IterateeOutput.Done(let scheme as String, let remaining):
      if remaining.isDone {
        return unexpected(input)
      } else {
        return cont(UriRestSchemeRestParser(scheme), remaining)
      }
    default:
      return output
    }
  }
}

private struct UriRestSchemeRestParser: Iteratee {
  private let scheme: String?

  private init(_ scheme: String?) {
    self.scheme = scheme
  }

  private func feed(input: IterateeInput) -> IterateeOutput {
    if let c = input.head where c == ":" {
      return cont(UriRestAuthorityPathQueryFragmentParser(scheme), input.tail)
    } else if !input.isEmpty {
      return expected(":", input)
    } else if input.isDone {
      return unexpected(input)
    }
    return cont(UriRestSchemeRestParser(scheme), input)
  }
}

private struct UriRestAuthorityPathQueryFragmentParser: Iteratee {
  private let scheme: String?

  private init(_ scheme: String? = nil) {
    self.scheme = scheme
  }

  private func feed(input: IterateeInput) -> IterateeOutput {
    if let c = input.head {
      switch c {
      case "/":
        return cont(UriRestAuthorityPathParser(scheme), input.tail)
      case "?":
        return cont(UriRestQueryParser(scheme), input.tail)
      case "#":
        return cont(UriRestFragmentParser(scheme), input.tail)
      default:
        return cont(UriRestPathParser(scheme), input)
      }
    } else if input.isDone {
      return done(Uri(scheme: scheme), input)
    }
    return cont(UriRestAuthorityPathQueryFragmentParser(scheme), input)
  }
}

private struct UriRestAuthorityPathParser: Iteratee {
  private let scheme: String?

  private init(_ scheme: String? = nil) {
    self.scheme = scheme
  }

  private func feed(input_: IterateeInput) -> IterateeOutput {
    var input = input_
    if let c = input.head {
      if c == "/" {
        input = input.tail
        if input.isEmpty || input.isDone {
          return done(Uri(scheme: scheme), input)
        } else {
          return cont(UriRestAuthorityParser(scheme), input)
        }
      } else {
        return cont(UriRestPathParser(scheme, nil, UriPathParser("/")), input)
      }
    } else if input.isDone {
      return done(Uri(scheme: scheme, path: Uri.Path.Slash(Uri.Path.Empty)), input)
    }
    return cont(UriRestAuthorityPathParser(scheme), input)
  }
}

private struct UriRestAuthorityParser: Iteratee {
  private let scheme: String?
  private let authority: Iteratee

  private init(_ scheme: String? = nil, _ authority: Iteratee = UriAuthorityParser()) {
    self.scheme = scheme
    self.authority = authority
  }

  private func feed(input: IterateeInput) -> IterateeOutput {
    var output = cont(authority, input)
    while case IterateeOutput.Cont(let next, let remaining) = output where !remaining.isEmpty || remaining.isDone {
      output = next.feed(remaining)
    }
    switch output {
    case IterateeOutput.Cont(let next, let remaining):
      return cont(UriRestAuthorityParser(scheme, next), remaining)
    case IterateeOutput.Done(let authority as Uri.Authority, let remaining):
      if remaining.isDone {
        return done(Uri(scheme: scheme, authority: authority), remaining)
      } else {
        return cont(UriRestAuthorityRestParser(scheme, authority), remaining)
      }
    default:
      return output
    }
  }
}

private struct UriRestAuthorityRestParser: Iteratee {
  private let scheme: String?
  private let authority: Uri.Authority?

  private init(_ scheme: String?, _ authority: Uri.Authority?) {
    self.scheme = scheme
    self.authority = authority
  }

  private func feed(input: IterateeInput) -> IterateeOutput {
    if let c = input.head {
      switch c {
      case "?":
        return cont(UriRestQueryParser(scheme, authority), input.tail)
      case "#":
        return cont(UriRestFragmentParser(scheme, authority), input.tail)
      default:
        return cont(UriRestPathParser(scheme, authority), input)
      }
    } else if input.isDone {
      return done(Uri(scheme: scheme, authority: authority), input)
    }
    return cont(UriRestAuthorityRestParser(scheme, authority), input)
  }
}

private struct UriRestPathParser: Iteratee {
  private let scheme: String?
  private let authority: Uri.Authority?
  private let path: Iteratee

  private init(_ scheme: String? = nil, _ authority: Uri.Authority? = nil, _ path: Iteratee = UriPathParser()) {
    self.scheme = scheme
    self.authority = authority
    self.path = path
  }

  private func feed(input: IterateeInput) -> IterateeOutput {
    var output = cont(path, input)
    while case IterateeOutput.Cont(let next, let remaining) = output where !remaining.isEmpty || remaining.isDone {
      output = next.feed(remaining)
    }
    switch output {
    case IterateeOutput.Cont(let next, let remaining):
      return cont(UriRestPathParser(scheme, authority, next), remaining)
    case IterateeOutput.Done(let path as Uri.Path, let remaining):
      if remaining.isDone {
        return done(Uri(scheme: scheme, authority: authority, path: path), remaining)
      } else {
        return cont(UriRestPathRestParser(scheme, authority, path), remaining)
      }
    default:
      return output
    }
  }
}

private struct UriRestPathRestParser: Iteratee {
  private let scheme: String?
  private let authority: Uri.Authority?
  private let path: Uri.Path

  private init(_ scheme: String?, _ authority: Uri.Authority?, _ path: Uri.Path) {
    self.scheme = scheme
    self.authority = authority
    self.path = path
  }

  private func feed(input: IterateeInput) -> IterateeOutput {
    if let c = input.head {
      switch c {
      case "?":
        return cont(UriRestQueryParser(scheme, authority, path), input.tail)
      case "#":
        return cont(UriRestFragmentParser(scheme, authority, path), input.tail)
      default:
        return done(Uri(scheme: scheme, authority: authority, path: path), input)
      }
    } else if input.isDone {
      return done(Uri(scheme: scheme, authority: authority, path: path), input)
    }
    return cont(UriRestPathRestParser(scheme, authority, path), input)
  }
}

private struct UriRestQueryParser: Iteratee {
  private let scheme: String?
  private let authority: Uri.Authority?
  private let path: Uri.Path
  private let query: Iteratee

  private init(_ scheme: String? = nil, _ authority: Uri.Authority? = nil, _ path: Uri.Path = Uri.Path.Empty, _ query: Iteratee = UriQueryParser()) {
    self.scheme = scheme
    self.authority = authority
    self.path = path
    self.query = query
  }

  private func feed(input: IterateeInput) -> IterateeOutput {
    var output = cont(query, input)
    while case IterateeOutput.Cont(let next, let remaining) = output where !remaining.isEmpty || remaining.isDone {
      output = next.feed(remaining)
    }
    switch output {
    case IterateeOutput.Cont(let next, let remaining):
      return cont(UriRestQueryParser(scheme, authority, path, next), remaining)
    case IterateeOutput.Done(let query as Uri.Query, let remaining):
      if remaining.isDone {
        return done(Uri(scheme: scheme, authority: authority, path: path, query: query), remaining)
      } else {
        return cont(UriRestQueryRestParser(scheme, authority, path, query), remaining)
      }
    default:
      return output
    }
  }
}

private struct UriRestQueryRestParser: Iteratee {
  private let scheme: String?
  private let authority: Uri.Authority?
  private let path: Uri.Path
  private let query: Uri.Query

  private init(_ scheme: String?, _ authority: Uri.Authority?, _ path: Uri.Path, _ query: Uri.Query) {
    self.scheme = scheme
    self.authority = authority
    self.path = path
    self.query = query
  }

  private func feed(input: IterateeInput) -> IterateeOutput {
    if let c = input.head {
      if c == "#" {
        return cont(UriRestFragmentParser(scheme, authority, path, query), input.tail)
      } else {
        return done(Uri(scheme: scheme, authority: authority, path: path, query: query), input)
      }
    } else if input.isDone {
      return done(Uri(scheme: scheme, authority: authority, path: path, query: query), input)
    }
    return cont(UriRestQueryRestParser(scheme, authority, path, query), input)
  }
}

private struct UriRestFragmentParser: Iteratee {
  private let scheme: String?
  private let authority: Uri.Authority?
  private let path: Uri.Path
  private let query: Uri.Query?
  private let fragment: Iteratee

  private init(_ scheme: String? = nil, _ authority: Uri.Authority? = nil, _ path: Uri.Path = Uri.Path.Empty, _ query: Uri.Query? = nil, _ fragment: Iteratee = UriFragmentParser()) {
    self.scheme = scheme
    self.authority = authority
    self.path = path
    self.query = query
    self.fragment = fragment
  }

  private func feed(input: IterateeInput) -> IterateeOutput {
    var output = cont(fragment, input)
    while case IterateeOutput.Cont(let next, let remaining) = output where !remaining.isEmpty || remaining.isDone {
      output = next.feed(remaining)
    }
    switch output {
    case IterateeOutput.Cont(let next, let remaining):
      return cont(UriRestFragmentParser(scheme, authority, path, query, next), remaining)
    case IterateeOutput.Done(let fragment as Uri.Fragment, let remaining):
      return done(Uri(scheme: scheme, authority: authority, path: path, query: query, fragment: fragment), remaining)
    default:
      return output
    }
  }
}


struct UriSchemeParser: Iteratee {
  func feed(input: IterateeInput) -> IterateeOutput {
    if let c = input.head where isAlpha(c) {
      return cont(UriSchemeRestParser(String(toLowerCase(c))), input.tail)
    } else if !input.isEmpty || input.isDone {
      return expected("scheme", input)
    }
    return cont(self, input)
  }
}

private struct UriSchemeRestParser: Iteratee {
  private let scheme: String

  private init(_ scheme: String) {
    self.scheme = scheme;
  }

  private func feed(input_: IterateeInput) -> IterateeOutput {
    var input = input_
    var scheme = self.scheme
    while let c = input.head where isSchemeChar(c) {
      scheme.append(toLowerCase(c))
      input = input.tail
    }
    if !input.isEmpty || input.isDone {
      return done(scheme, input)
    }
    return cont(UriSchemeRestParser(scheme), input)
  }
}


struct UriAuthorityParser: Iteratee {
  func feed(input: IterateeInput) -> IterateeOutput {
    if !input.isEmpty {
      var look = input
      while let c = look.head where c != "@" && c != "/" {
        look = look.tail
      }
      if let c = look.head where c == "@" {
        return UriAuthorityUserInfoParser().feed(input)
      } else {
        return UriAuthorityHostParser().feed(input)
      }
    } else if input.isDone {
      return done(nil as Uri.Authority?, input)
    }
    return cont(self, input)
  }
}

private struct UriAuthorityUserInfoParser: Iteratee {
  private let userInfo: Iteratee

  private init(_ userInfo: Iteratee = UriUserInfoParser()) {
    self.userInfo = userInfo
  }

  private func feed(input: IterateeInput) -> IterateeOutput {
    var output = cont(userInfo, input)
    while case IterateeOutput.Cont(let next, let remaining) = output where !remaining.isEmpty || remaining.isDone {
      output = next.feed(remaining)
    }
    switch output {
    case IterateeOutput.Cont(let next, let remaining):
      return cont(UriAuthorityUserInfoParser(next), remaining)
    case IterateeOutput.Done(let userInfo as Uri.UserInfo, let remaining):
      if remaining.isDone {
        return unexpected(remaining)
      } else {
        return cont(UriAuthorityUserInfoRestParser(userInfo), remaining)
      }
    default:
      return output
    }
  }
}

private struct UriAuthorityUserInfoRestParser: Iteratee {
  private let userInfo: Uri.UserInfo

  private init(_ userInfo: Uri.UserInfo) {
    self.userInfo = userInfo
  }

  private func feed(input: IterateeInput) -> IterateeOutput {
    if let c = input.head {
      if c == "@" {
        return cont(UriAuthorityHostParser(userInfo), input.tail)
      } else {
        return expected("@", input)
      }
    } else if input.isDone {
      return unexpected(input)
    }
    return cont(UriAuthorityUserInfoRestParser(userInfo), input)
  }
}

private struct UriAuthorityHostParser: Iteratee {
  private let userInfo: Uri.UserInfo?
  private let host: Iteratee

  private init(_ userInfo: Uri.UserInfo? = nil, _ host: Iteratee = UriHostParser()) {
    self.userInfo = userInfo
    self.host = host
  }

  private func feed(input: IterateeInput) -> IterateeOutput {
    var output = cont(host, input)
    while case IterateeOutput.Cont(let next, let remaining) = output where !remaining.isEmpty || remaining.isDone {
      output = next.feed(remaining)
    }
    switch output {
    case IterateeOutput.Cont(let next, let remaining):
      return cont(UriAuthorityHostParser(userInfo, next), remaining)
    case IterateeOutput.Done(let host as Uri.Host, let remaining):
      if remaining.isDone {
        return done(Uri.Authority(userInfo: userInfo, host: host), remaining)
      } else {
        return cont(UriAuthorityHostRestParser(userInfo, host), remaining)
      }
    default:
      return output
    }
  }
}

private struct UriAuthorityHostRestParser: Iteratee {
  private let userInfo: Uri.UserInfo?
  private let host: Uri.Host

  private init(_ userInfo: Uri.UserInfo?, _ host: Uri.Host) {
    self.userInfo = userInfo
    self.host = host
  }

  private func feed(input: IterateeInput) -> IterateeOutput {
    if let c = input.head where c == ":" {
      return cont(UriAuthorityPortParser(userInfo, host), input.tail)
    }
    else if !input.isEmpty || input.isDone {
      return done(Uri.Authority(userInfo: userInfo, host: host), input)
    }
    return cont(UriAuthorityHostRestParser(userInfo, host), input)
  }
}

private struct UriAuthorityPortParser: Iteratee {
  private let userInfo: Uri.UserInfo?
  private let host: Uri.Host
  private let port: Iteratee

  private init(_ userInfo: Uri.UserInfo? = nil, _ host: Uri.Host, _ port: Iteratee = UriPortParser()) {
    self.userInfo = userInfo
    self.host = host
    self.port = port
  }

  private func feed(input: IterateeInput) -> IterateeOutput {
    var output = cont(port, input)
    while case IterateeOutput.Cont(let next, let remaining) = output where !remaining.isEmpty || remaining.isDone {
      output = next.feed(remaining)
    }
    switch output {
    case IterateeOutput.Cont(let next, let remaining):
      return cont(UriAuthorityPortParser(userInfo, host, next), remaining)
    case IterateeOutput.Done(let port as UInt16, let remaining):
      return done(Uri.Authority(userInfo: userInfo, host: host, port: port), remaining)
    default:
      return output
    }
  }
}


struct UriUserInfoParser: Iteratee {
  private let part: String

  init(_ part: String = "") {
    self.part = part
  }

  func feed(input_: IterateeInput) -> IterateeOutput {
    var input = input_
    var part = self.part
    while let c = input.head where isUserChar(c) {
      part.append(c)
      input = input.tail
    }
    if let c = input.head {
      switch c {
      case ":":
        return cont(UriUserInfoPasswordParser(part), input.tail)
      case "%":
        return cont(UriUserInfoEscape1Parser(part), input.tail)
      default:
        return done(Uri.UserInfo.Part(part), input)
      }
    } else if input.isDone {
      return done(Uri.UserInfo.Part(part), input)
    }
    return cont(UriUserInfoParser(part), input)
  }
}

private struct UriUserInfoEscape1Parser: Iteratee {
  private let part: String

  private init(_ part: String) {
    self.part = part
  }

  private func feed(input: IterateeInput) -> IterateeOutput {
    if let c1 = input.head where isHexChar(c1) {
      return cont(UriUserInfoEscape2Parser(part, c1), input.tail)
    } else if !input.isEmpty || input.isDone {
      return expected("hex digit", input)
    }
    return cont(UriUserInfoEscape1Parser(part), input)
  }
}

private struct UriUserInfoEscape2Parser: Iteratee {
  private let part: String
  private let c1: UnicodeScalar

  private init(_ part: String, _ c1: UnicodeScalar) {
    self.part = part
    self.c1 = c1
  }

  private func feed(input: IterateeInput) -> IterateeOutput {
    var part = self.part
    if let c2 = input.head where isHexChar(c2) {
      part.append(UnicodeScalar((decodeHex(c1) << 4) + decodeHex(c2)))
      return cont(UriUserInfoParser(part), input.tail)
    } else if !input.isEmpty || input.isDone {
      return expected("hex digit", input)
    }
    return cont(UriUserInfoEscape2Parser(part, c1), input)
  }
}

private struct UriUserInfoPasswordParser: Iteratee {
  private let username: String
  private let password: String

  private init(_ username: String, _ password: String = "") {
    self.username = username
    self.password = password
  }

  private func feed(input_: IterateeInput) -> IterateeOutput {
    var input = input_
    var password = self.password
    while let c = input.head where isUserInfoChar(c) {
      password.append(c)
      input = input.tail
    }
    if let c = input.head where c == "%" {
      return cont(UriUserInfoPasswordEscape1Parser(username, password), input.tail)
    } else if !input.isEmpty || input.isDone {
      return done(Uri.UserInfo.Login(username, password), input)
    }
    return cont(UriUserInfoPasswordParser(username, password), input)
  }
}

private struct UriUserInfoPasswordEscape1Parser: Iteratee {
  private let username: String
  private let password: String

  private init(_ username: String, _ password: String) {
    self.username = username
    self.password = password
  }

  private func feed(input: IterateeInput) -> IterateeOutput {
    if let c1 = input.head where isHexChar(c1) {
      return cont(UriUserInfoPasswordEscape2Parser(username, password, c1), input.tail)
    } else if !input.isEmpty || input.isDone {
      return expected("hex digit", input)
    }
    return cont(UriUserInfoPasswordEscape1Parser(username, password), input)
  }
}

private struct UriUserInfoPasswordEscape2Parser: Iteratee {
  private let username: String
  private let password: String
  private let c1: UnicodeScalar

  private init(_ username: String, _ password: String, _ c1: UnicodeScalar) {
    self.username = username
    self.password = password
    self.c1 = c1
  }

  private func feed(input: IterateeInput) -> IterateeOutput {
    var password = self.password
    if let c2 = input.head where isHexChar(c2) {
      password.append(UnicodeScalar((decodeHex(c1) << 4) + decodeHex(c2)))
      return cont(UriUserInfoPasswordParser(username, password), input.tail)
    } else if !input.isEmpty || input.isDone {
      return expected("hex digit", input)
    }
    return cont(UriUserInfoPasswordEscape2Parser(username, password, c1), input)
  }
}


struct UriHostParser: Iteratee {
  func feed(input: IterateeInput) -> IterateeOutput {
    if let c = input.head {
      if c == "[" {
        return UriHostIPv6RestParser().feed(input.tail)
      } else {
        return UriHostAddressParser().feed(input)
      }
    } else if input.isDone {
      return done(Uri.Host.Name(""), input)
    }
    return cont(self, input)
  }
}

private struct UriHostAddressParser: Iteratee {
  private let address: String
  private let x: UInt32
  private let i: UInt32

  private init(_ address: String = "", _ x: UInt32 = 0, _ i: UInt32 = 1) {
    self.address = address
    self.x = x
    self.i = i
  }

  private func feed(input_: IterateeInput) -> IterateeOutput {
    var input = input_
    var address = self.address
    var x = self.x
    while let c = input.head where isDigit(c) {
      address.append(c)
      x = 10 * x + decodeDigit(c)
      input = input.tail
    }
    if let c = input.head {
      if c == "." && x <= 255 && i < 4 {
        address.append(c)
        return UriHostAddressParser(address, 0, i + 1).feed(input.tail)
      } else if !isHostChar(c) && c != "%" && x <= 255 && i == 4 {
        return done(Uri.Host.IPv4(address), input)
      } else {
        return UriHostNameParser(address).feed(input)
      }
    } else if input.isDone {
      if x <= 255 && i == 4 {
        return done(Uri.Host.IPv4(address), input)
      } else {
        return done(Uri.Host.Name(address), input)
      }
    }
    return cont(UriHostAddressParser(address, x, i), input)
  }
}

private struct UriHostNameParser: Iteratee {
  private let name: String

  private init(_ name: String) {
    self.name = name
  }

  private func feed(input_: IterateeInput) -> IterateeOutput {
    var input = input_
    var name = self.name
    while let c = input.head where isHostChar(c) {
      name.append(toLowerCase(c))
      input = input.tail
    }
    if let c = input.head where c == "%" {
      return cont(UriHostNameEscape1Parser(name), input.tail)
    } else if !input.isEmpty || input.isDone {
      return done(Uri.Host.Name(name), input)
    }
    return cont(UriHostNameParser(name), input)
  }
}

private struct UriHostNameEscape1Parser: Iteratee {
  private let name: String

  private init(_ name: String) {
    self.name = name
  }

  private func feed(input: IterateeInput) -> IterateeOutput {
    if let c1 = input.head where isHexChar(c1) {
      return cont(UriHostNameEscape2Parser(name, c1), input.tail)
    } else if !input.isEmpty || input.isDone {
      return expected("hex digit", input)
    }
    return cont(UriHostNameEscape1Parser(name), input)
  }
}

private struct UriHostNameEscape2Parser: Iteratee {
  private let name: String
  private let c1: UnicodeScalar

  private init(_ name: String, _ c1: UnicodeScalar) {
    self.name = name
    self.c1 = c1
  }

  private func feed(input: IterateeInput) -> IterateeOutput {
    var name = self.name
    if let c2 = input.head where isHexChar(c2) {
      name.append(UnicodeScalar((decodeHex(c1) << 4) + decodeHex(c2)))
      return cont(UriHostNameParser(name), input.tail)
    } else if !input.isEmpty || input.isDone {
      return expected("hex digit", input)
    }
    return cont(UriHostNameEscape2Parser(name, c1), input)
  }
}

private struct UriHostIPv6RestParser: Iteratee {
  let address: String

  private init(_ address: String = "") {
    self.address = address
  }

  private func feed(input_: IterateeInput) -> IterateeOutput {
    var input = input_
    var address = self.address
    while let c = input.head where isHostChar(c) || c == ":" {
      address.append(c)
      input = input.tail
    }
    if let c = input.head where c == "]" {
      return done(Uri.Host.IPv6(address), input.tail)
    } else if !input.isEmpty || input.isDone {
      return expected("IPv6 address", input)
    }
    return cont(UriHostIPv6RestParser(address), input)
  }
}


struct UriPortParser: Iteratee {
  private let port: UInt16

  init(_ port: UInt16 = 0) {
    self.port = port
  }

  func feed(input_: IterateeInput) -> IterateeOutput {
    var input = input_
    var port = self.port
    while let c = input.head where isDigit(c) {
      port = 10 * port + UInt16(decodeDigit(c))
      input = input.tail
    }
    if !input.isEmpty || input.isDone {
      return done(port, input)
    }
    return cont(UriPortParser(port), input)
  }
}


struct UriPathParser: Iteratee {
  private let segments: [String]
  private let segment: String

  init(_ segments: [String] = [], _ segment: String = "") {
    self.segments = segments
    self.segment = segment
  }

  private init(_ segment: String) {
    self.init([segment])
  }

  func feed(input_: IterateeInput) -> IterateeOutput {
    var input = input_
    var segments = self.segments
    var segment = self.segment
    while let c = input.head where isPathChar(c) {
      segment.append(c)
      input = input.tail
    }
    if let c = input.head {
      if c == "/" {
        if !segment.isEmpty {
          segments.append(segment)
          segment = ""
        }
        segments.append("/")
        return cont(UriPathParser(segments), input.tail)
      } else if c == "%" {
        return cont(UriPathEscape1Parser(segments, segment), input.tail)
      }
    }
    if !input.isEmpty || input.isDone {
      if !segment.isEmpty {
        segments.append(segment)
      }
      return done(Uri.Path(segments), input)
    }
    return cont(UriPathParser(segments, segment), input)
  }
}

private struct UriPathEscape1Parser: Iteratee {
  private let segments: [String]
  private let segment: String

  private init(_ segments: [String], _ segment: String) {
    self.segments = segments
    self.segment = segment
  }

  private func feed(input: IterateeInput) -> IterateeOutput {
    if let c1 = input.head where isHexChar(c1) {
      return cont(UriPathEscape2Parser(segments, segment, c1), input.tail)
    } else if !input.isEmpty || input.isDone {
      return expected("hex digit", input)
    }
    return cont(UriPathEscape1Parser(segments, segment), input)
  }
}

private struct UriPathEscape2Parser: Iteratee {
  private let segments: [String]
  private let segment: String
  private let c1: UnicodeScalar

  private init(_ segments: [String], _ segment: String, _ c1: UnicodeScalar) {
    self.segments = segments
    self.segment = segment
    self.c1 = c1
  }

  private func feed(input: IterateeInput) -> IterateeOutput {
    var segment = self.segment
    if let c2 = input.head where isHexChar(c2) {
      segment.append(UnicodeScalar((decodeHex(c1) << 4) + decodeHex(c2)))
      return cont(UriPathParser(segments, segment), input.tail)
    } else if !input.isEmpty || input.isDone {
      return expected("hex digit", input)
    }
    return cont(UriPathEscape2Parser(segments, segment, c1), input)
  }
}


struct UriQueryParser: Iteratee {
  private let params: [(String?, String)]
  private let part: String

  init(_ params: [(String?, String)] = [], _ part: String = "") {
    self.params = params
    self.part = part
  }

  func feed(input_: IterateeInput) -> IterateeOutput {
    var input = input_
    var params = self.params
    var part = self.part
    while let c = input.head where isParamChar(c) {
      part.append(c)
      input = input.tail
    }
    if let c = input.head {
      if c == "=" {
        return cont(UriQueryValueParser(params, part), input.tail)
      } else if c == "&" {
        params.append((nil, part))
        return cont(UriQueryParser(params), input.tail)
      } else if c == "%" {
        return cont(UriQueryEscape1Parser(params, part), input.tail)
      }
    }
    if !input.isEmpty || input.isDone {
      if params.isEmpty {
        return done(Uri.Query(part: part), input)
      } else {
        params.append((nil, part))
        return done(Uri.Query(params), input)
      }
    }
    return cont(UriQueryParser(params, part), input)
  }
}

private struct UriQueryEscape1Parser: Iteratee {
  private let params: [(String?, String)]
  private let part: String

  private init(_ params: [(String?, String)], _ part: String) {
    self.params = params
    self.part = part
  }

  private func feed(input: IterateeInput) -> IterateeOutput {
    if let c1 = input.head where isHexChar(c1) {
      return cont(UriQueryEscape2Parser(params, part, c1), input.tail)
    } else if !input.isEmpty || input.isDone {
      return expected("hex digit", input)
    }
    return cont(UriQueryEscape1Parser(params, part), input)
  }
}

private struct UriQueryEscape2Parser: Iteratee {
  private let params: [(String?, String)]
  private let part: String
  private let c1: UnicodeScalar

  private init(_ params: [(String?, String)], _ part: String, _ c1: UnicodeScalar) {
    self.params = params
    self.part = part
    self.c1 = c1
  }

  private func feed(input: IterateeInput) -> IterateeOutput {
    var part = self.part
    if let c2 = input.head where isHexChar(c2) {
      part.append(UnicodeScalar((decodeHex(c1) << 4) + decodeHex(c2)))
      return cont(UriQueryParser(params, part), input.tail)
    } else if !input.isEmpty || input.isDone {
      return expected("hex digit", input)
    }
    return cont(UriQueryEscape2Parser(params, part, c1), input)
  }
}

private struct UriQueryValueParser: Iteratee {
  private let params: [(String?, String)]
  private let key: String
  private let value: String

  private init(_ params: [(String?, String)], _ key: String, _ value: String = "") {
    self.params = params
    self.key = key
    self.value = value
  }

  private func feed(input_: IterateeInput) -> IterateeOutput {
    var input = input_
    var params = self.params
    var value = self.value
    while let c = input.head where isParamChar(c) || c == "=" {
      value.append(c)
      input = input.tail
    }
    if let c = input.head {
      if c == "&" {
        params.append((key, value))
        return cont(UriQueryParser(params), input.tail)
      } else if c == "%" {
        return cont(UriQueryValueEscape1Parser(params, key, value), input.tail)
      }
    }
    if !input.isEmpty || input.isDone {
      params.append((key, value))
      return done(Uri.Query(params), input)
    }
    return cont(UriQueryValueParser(params, key, value), input)
  }
}

private struct UriQueryValueEscape1Parser: Iteratee {
  private let params: [(String?, String)]
  private let key: String
  private let value: String

  private init(_ params: [(String?, String)], _ key: String, _ value: String) {
    self.params = params
    self.key = key
    self.value = value
  }

  private func feed(input: IterateeInput) -> IterateeOutput {
    if let c1 = input.head where isHexChar(c1) {
      return cont(UriQueryValueEscape2Parser(params, key, value, c1), input.tail)
    } else if !input.isEmpty || input.isDone {
      return expected("hex digit", input)
    }
    return cont(UriQueryValueEscape1Parser(params, key, value), input)
  }
}

private struct UriQueryValueEscape2Parser: Iteratee {
  private let params: [(String?, String)]
  private let key: String
  private let value: String
  private let c1: UnicodeScalar

  private init(_ params: [(String?, String)], _ key: String, _ value: String, _ c1: UnicodeScalar) {
    self.params = params
    self.key = key
    self.value = value
    self.c1 = c1
  }

  private func feed(input: IterateeInput) -> IterateeOutput {
    var value = self.value
    if let c2 = input.head where isHexChar(c2) {
      value.append(UnicodeScalar((decodeHex(c1) << 4) + decodeHex(c2)))
      return cont(UriQueryValueParser(params, key, value), input.tail)
    } else if !input.isEmpty || input.isDone {
      return expected("hex digit", input)
    }
    return cont(UriQueryValueEscape2Parser(params, key, value, c1), input)
  }
}


struct UriFragmentParser: Iteratee {
  private let fragment: String

  init(_ fragment: String = "") {
    self.fragment = fragment
  }

  func feed(input_: IterateeInput) -> IterateeOutput {
    var input = input_
    var fragment = self.fragment
    while let c = input.head where isFragmentChar(c) {
      fragment.append(c)
      input = input.tail
    }
    if let c = input.head where c == "%" {
      return cont(UriFragmentEscape1Parser(fragment), input.tail)
    } else if !input.isEmpty || input.isDone {
      return done(Uri.Fragment(fragment), input)
    }
    return cont(UriFragmentParser(fragment), input)
  }
}

private struct UriFragmentEscape1Parser: Iteratee {
  private let fragment: String

  private init(_ fragment: String) {
    self.fragment = fragment
  }

  private func feed(input: IterateeInput) -> IterateeOutput {
    if let c1 = input.head where isHexChar(c1) {
      return cont(UriFragmentEscape2Parser(fragment, c1), input.tail)
    } else if !input.isEmpty || input.isDone {
      return expected("hex digit", input)
    }
    return cont(UriFragmentEscape1Parser(fragment), input)
  }
}

private struct UriFragmentEscape2Parser: Iteratee {
  private let fragment: String
  private let c1: UnicodeScalar

  private init(_ fragment: String, _ c1: UnicodeScalar) {
    self.fragment = fragment
    self.c1 = c1
  }

  private func feed(input: IterateeInput) -> IterateeOutput {
    var fragment = self.fragment
    if let c2 = input.head where isHexChar(c2) {
      fragment.append(UnicodeScalar((decodeHex(c1) << 4) + decodeHex(c2)))
      return cont(UriFragmentParser(fragment), input.tail)
    } else if !input.isEmpty || input.isDone {
      return expected("hex digit", input)
    }
    return cont(UriFragmentEscape2Parser(fragment, c1), input)
  }
}


private func isUnreservedChar(c: UnicodeScalar) -> Bool {
  return c == "-" || c == "." ||
    c >= "0" && c <= "9" ||
    c >= "A" && c <= "Z" ||
    c == "_" ||
    c >= "a" && c <= "z" ||
    c == "~"
}

private func isSubDelimChar(c: UnicodeScalar) -> Bool {
  return c == "!" || c == "$" ||
    c == "&" || c == "'" ||
    c == "(" || c == ")" ||
    c == "*" || c == "+" ||
    c == "," || c == ";" ||
    c == "="
}

func isSchemeChar(c: UnicodeScalar) -> Bool {
  return c == "+" || c == "-" || c == "." ||
    c >= "0" && c <= "9" ||
    c >= "A" && c <= "Z" ||
    c >= "a" && c <= "z"
}

func isUserInfoChar(c: UnicodeScalar) -> Bool {
  return isUnreservedChar(c) || isSubDelimChar(c) || c == ":"
}

func isUserChar(c: UnicodeScalar) -> Bool {
  return isUnreservedChar(c) || isSubDelimChar(c)
}

func isHostChar(c: UnicodeScalar) -> Bool {
  return isUnreservedChar(c) || isSubDelimChar(c)
}

func isPathChar(c: UnicodeScalar) -> Bool {
  return isUnreservedChar(c) || isSubDelimChar(c) || c == ":" || c == "@"
}

func isQueryChar(c: UnicodeScalar) -> Bool {
  return isUnreservedChar(c) || isSubDelimChar(c) || c == "/" || c == ":" || c == "?" || c == "@"
}

func isParamChar(c: UnicodeScalar) -> Bool {
  return isUnreservedChar(c) ||
    c == "!" || c == "$" ||
    c == "'" || c == "(" ||
    c == ")" || c == "*" ||
    c == "+" || c == "," ||
    c == "/" || c == ":" ||
    c == ";" || c == "?" ||
    c == "@"
}

func isFragmentChar(c: UnicodeScalar) -> Bool {
  return isUnreservedChar(c) || isSubDelimChar(c) || c == "/" || c == ":" || c == "?" || c == "@"
}

func isAlpha(c: UnicodeScalar) -> Bool {
  return c >= "A" && c <= "Z" || c >= "a" && c <= "z"
}

private func isDigit(c: UnicodeScalar) -> Bool {
  return c >= "0" && c <= "9"
}

private func isHexChar(c: UnicodeScalar) -> Bool {
  return c >= "0" && c <= "9" ||
    c >= "A" && c <= "F" ||
    c >= "a" && c <= "f"
}

private func toLowerCase(c: UnicodeScalar) -> UnicodeScalar {
  if c >= "A" && c <= "Z" {
    return UnicodeScalar(c.value + (UnicodeScalar("a").value - UnicodeScalar("A").value))
  } else {
    return c
  }
}

private func decodeDigit(c: UnicodeScalar) -> UInt32 {
  if c >= "0" && c <= "9" {
    return c.value - UnicodeScalar("0").value
  } else {
    fatalError("invalid digit")
  }
}

private func decodeHex(c: UnicodeScalar) -> UInt32 {
  if c >= "0" && c <= "9" {
    return c.value - UnicodeScalar("0").value
  } else if c >= "A" && c <= "F" {
    return 10 + (c.value - UnicodeScalar("A").value)
  } else if c >= "a" && c <= "f" {
    return 10 + (c.value - UnicodeScalar("a").value)
  } else {
    fatalError("invalid hex char")
  }
}
