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

struct UriRestSchemeParser: Iteratee {
  let scheme: Iteratee

  init(_ scheme: Iteratee = UriSchemeParser()) {
    self.scheme = scheme
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    var output = cont(scheme, input)
    while case IterateeOutput.Cont(let next, let remaining) = output where !remaining.isEmpty || remaining.isDone {
      output = next.feed(remaining)
    }
    switch output {
    case IterateeOutput.Cont(let next, let remaining):
      return cont(UriRestSchemeParser(next), remaining)
    case IterateeOutput.Done(let scheme as Uri.Scheme, let remaining):
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

struct UriRestSchemeRestParser: Iteratee {
  let scheme: Uri.Scheme?

  init(_ scheme: Uri.Scheme?) {
    self.scheme = scheme
  }

  func feed(input: IterateeInput) -> IterateeOutput {
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

struct UriRestAuthorityPathQueryFragmentParser: Iteratee {
  let scheme: Uri.Scheme?

  init(_ scheme: Uri.Scheme? = nil) {
    self.scheme = scheme
  }

  func feed(input: IterateeInput) -> IterateeOutput {
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

struct UriRestAuthorityPathParser: Iteratee {
  let scheme: Uri.Scheme?

  init(_ scheme: Uri.Scheme? = nil) {
    self.scheme = scheme
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
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

struct UriRestAuthorityParser: Iteratee {
  let scheme: Uri.Scheme?
  let authority: Iteratee

  init(_ scheme: Uri.Scheme? = nil, _ authority: Iteratee = UriAuthorityParser()) {
    self.scheme = scheme
    self.authority = authority
  }

  func feed(input: IterateeInput) -> IterateeOutput {
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

struct UriRestAuthorityRestParser: Iteratee {
  let scheme: Uri.Scheme?
  let authority: Uri.Authority?

  init(_ scheme: Uri.Scheme?, _ authority: Uri.Authority?) {
    self.scheme = scheme
    self.authority = authority
  }

  func feed(input: IterateeInput) -> IterateeOutput {
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

struct UriRestPathParser: Iteratee {
  let scheme: Uri.Scheme?
  let authority: Uri.Authority?
  let path: Iteratee

  init(_ scheme: Uri.Scheme? = nil, _ authority: Uri.Authority? = nil, _ path: Iteratee = UriPathParser()) {
    self.scheme = scheme
    self.authority = authority
    self.path = path
  }

  func feed(input: IterateeInput) -> IterateeOutput {
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

struct UriRestPathRestParser: Iteratee {
  let scheme: Uri.Scheme?
  let authority: Uri.Authority?
  let path: Uri.Path

  init(_ scheme: Uri.Scheme?, _ authority: Uri.Authority?, _ path: Uri.Path) {
    self.scheme = scheme
    self.authority = authority
    self.path = path
  }

  func feed(input: IterateeInput) -> IterateeOutput {
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

struct UriRestQueryParser: Iteratee {
  let scheme: Uri.Scheme?
  let authority: Uri.Authority?
  let path: Uri.Path
  let query: Iteratee

  init(_ scheme: Uri.Scheme? = nil, _ authority: Uri.Authority? = nil, _ path: Uri.Path = Uri.Path.Empty, _ query: Iteratee = UriQueryParser()) {
    self.scheme = scheme
    self.authority = authority
    self.path = path
    self.query = query
  }

  func feed(input: IterateeInput) -> IterateeOutput {
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

struct UriRestQueryRestParser: Iteratee {
  let scheme: Uri.Scheme?
  let authority: Uri.Authority?
  let path: Uri.Path
  let query: Uri.Query

  init(_ scheme: Uri.Scheme?, _ authority: Uri.Authority?, _ path: Uri.Path, _ query: Uri.Query) {
    self.scheme = scheme
    self.authority = authority
    self.path = path
    self.query = query
  }

  func feed(input: IterateeInput) -> IterateeOutput {
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

struct UriRestFragmentParser: Iteratee {
  let scheme: Uri.Scheme?
  let authority: Uri.Authority?
  let path: Uri.Path
  let query: Uri.Query?
  let fragment: Iteratee

  init(_ scheme: Uri.Scheme? = nil, _ authority: Uri.Authority? = nil, _ path: Uri.Path = Uri.Path.Empty, _ query: Uri.Query? = nil, _ fragment: Iteratee = UriFragmentParser()) {
    self.scheme = scheme
    self.authority = authority
    self.path = path
    self.query = query
    self.fragment = fragment
  }

  func feed(input: IterateeInput) -> IterateeOutput {
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

struct UriSchemeRestParser: Iteratee {
  let scheme: String

  init(_ scheme: String) {
    self.scheme = scheme;
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
    var scheme = self.scheme
    while let c = input.head where isSchemeChar(c) {
      scheme.append(toLowerCase(c))
      input = input.tail
    }
    if !input.isEmpty || input.isDone {
      return done(Uri.Scheme(scheme), input)
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

struct UriAuthorityUserInfoParser: Iteratee {
  let userInfo: Iteratee

  init(_ userInfo: Iteratee = UriUserInfoParser()) {
    self.userInfo = userInfo
  }

  func feed(input: IterateeInput) -> IterateeOutput {
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

struct UriAuthorityUserInfoRestParser: Iteratee {
  let userInfo: Uri.UserInfo

  init(_ userInfo: Uri.UserInfo) {
    self.userInfo = userInfo
  }

  func feed(input: IterateeInput) -> IterateeOutput {
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

struct UriAuthorityHostParser: Iteratee {
  let userInfo: Uri.UserInfo?
  let host: Iteratee

  init(_ userInfo: Uri.UserInfo? = nil, _ host: Iteratee = UriHostParser()) {
    self.userInfo = userInfo
    self.host = host
  }

  func feed(input: IterateeInput) -> IterateeOutput {
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

struct UriAuthorityHostRestParser: Iteratee {
  let userInfo: Uri.UserInfo?
  let host: Uri.Host

  init(_ userInfo: Uri.UserInfo?, _ host: Uri.Host) {
    self.userInfo = userInfo
    self.host = host
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    if let c = input.head where c == ":" {
      return cont(UriAuthorityPortParser(userInfo, host), input.tail)
    }
    else if !input.isEmpty || input.isDone {
      return done(Uri.Authority(userInfo: userInfo, host: host), input)
    }
    return cont(UriAuthorityHostRestParser(userInfo, host), input)
  }
}

struct UriAuthorityPortParser: Iteratee {
  let userInfo: Uri.UserInfo?
  let host: Uri.Host
  let port: Iteratee

  init(_ userInfo: Uri.UserInfo? = nil, _ host: Uri.Host, _ port: Iteratee = UriPortParser()) {
    self.userInfo = userInfo
    self.host = host
    self.port = port
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    var output = cont(port, input)
    while case IterateeOutput.Cont(let next, let remaining) = output where !remaining.isEmpty || remaining.isDone {
      output = next.feed(remaining)
    }
    switch output {
    case IterateeOutput.Cont(let next, let remaining):
      return cont(UriAuthorityPortParser(userInfo, host, next), remaining)
    case IterateeOutput.Done(let port as Uri.Port, let remaining):
      return done(Uri.Authority(userInfo: userInfo, host: host, port: port), remaining)
    default:
      return output
    }
  }
}


struct UriUserInfoParser: Iteratee {
  let part: String

  init(_ part: String = "") {
    self.part = part
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
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

struct UriUserInfoEscape1Parser: Iteratee {
  let part: String

  init(_ part: String) {
    self.part = part
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    if let c1 = input.head where isHexChar(c1) {
      return cont(UriUserInfoEscape2Parser(part, c1), input.tail)
    } else if !input.isEmpty || input.isDone {
      return expected("hex digit", input)
    }
    return cont(UriUserInfoEscape1Parser(part), input)
  }
}

struct UriUserInfoEscape2Parser: Iteratee {
  let part: String
  let c1: UnicodeScalar

  init(_ part: String, _ c1: UnicodeScalar) {
    self.part = part
    self.c1 = c1
  }

  func feed(input: IterateeInput) -> IterateeOutput {
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

struct UriUserInfoPasswordParser: Iteratee {
  let username: String
  let password: String

  init(_ username: String, _ password: String = "") {
    self.username = username
    self.password = password
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
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

struct UriUserInfoPasswordEscape1Parser: Iteratee {
  let username: String
  let password: String

  init(_ username: String, _ password: String) {
    self.username = username
    self.password = password
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    if let c1 = input.head where isHexChar(c1) {
      return cont(UriUserInfoPasswordEscape2Parser(username, password, c1), input.tail)
    } else if !input.isEmpty || input.isDone {
      return expected("hex digit", input)
    }
    return cont(UriUserInfoPasswordEscape1Parser(username, password), input)
  }
}

struct UriUserInfoPasswordEscape2Parser: Iteratee {
  let username: String
  let password: String
  let c1: UnicodeScalar

  init(_ username: String, _ password: String, _ c1: UnicodeScalar) {
    self.username = username
    self.password = password
    self.c1 = c1
  }

  func feed(input: IterateeInput) -> IterateeOutput {
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

struct UriHostAddressParser: Iteratee {
  let address: String
  let x: UInt32
  let i: UInt32

  init(_ address: String = "", _ x: UInt32 = 0, _ i: UInt32 = 1) {
    self.address = address
    self.x = x
    self.i = i
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
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

struct UriHostNameParser: Iteratee {
  let name: String

  init(_ name: String) {
    self.name = name
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
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

struct UriHostNameEscape1Parser: Iteratee {
  let name: String

  init(_ name: String) {
    self.name = name
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    if let c1 = input.head where isHexChar(c1) {
      return cont(UriHostNameEscape2Parser(name, c1), input.tail)
    } else if !input.isEmpty || input.isDone {
      return expected("hex digit", input)
    }
    return cont(UriHostNameEscape1Parser(name), input)
  }
}

struct UriHostNameEscape2Parser: Iteratee {
  let name: String
  let c1: UnicodeScalar

  init(_ name: String, _ c1: UnicodeScalar) {
    self.name = name
    self.c1 = c1
  }

  func feed(input: IterateeInput) -> IterateeOutput {
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

struct UriHostIPv6RestParser: Iteratee {
  let address: String

  init(_ address: String = "") {
    self.address = address
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
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
  let port: UInt16

  init(_ port: UInt16 = 0) {
    self.port = port
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
    var port = self.port
    while let c = input.head where isDigit(c) {
      port = 10 * port + UInt16(decodeDigit(c))
      input = input.tail
    }
    if !input.isEmpty || input.isDone {
      return done(Uri.Port(port), input)
    }
    return cont(UriPortParser(port), input)
  }
}


struct UriPathParser: Iteratee {
  let segments: [String]
  let segment: String

  init(_ segments: [String] = [], _ segment: String = "") {
    self.segments = segments
    self.segment = segment
  }

  init(_ segment: String) {
    self.init([segment])
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
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

struct UriPathEscape1Parser: Iteratee {
  let segments: [String]
  let segment: String

  init(_ segments: [String], _ segment: String) {
    self.segments = segments
    self.segment = segment
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    if let c1 = input.head where isHexChar(c1) {
      return cont(UriPathEscape2Parser(segments, segment, c1), input.tail)
    } else if !input.isEmpty || input.isDone {
      return expected("hex digit", input)
    }
    return cont(UriPathEscape1Parser(segments, segment), input)
  }
}

struct UriPathEscape2Parser: Iteratee {
  let segments: [String]
  let segment: String
  let c1: UnicodeScalar

  init(_ segments: [String], _ segment: String, _ c1: UnicodeScalar) {
    self.segments = segments
    self.segment = segment
    self.c1 = c1
  }

  func feed(input: IterateeInput) -> IterateeOutput {
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
  let params: [(String?, String)]
  let part: String

  init(_ params: [(String?, String)] = [], _ part: String = "") {
    self.params = params
    self.part = part
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
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

struct UriQueryEscape1Parser: Iteratee {
  let params: [(String?, String)]
  let part: String

  init(_ params: [(String?, String)], _ part: String) {
    self.params = params
    self.part = part
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    if let c1 = input.head where isHexChar(c1) {
      return cont(UriQueryEscape2Parser(params, part, c1), input.tail)
    } else if !input.isEmpty || input.isDone {
      return expected("hex digit", input)
    }
    return cont(UriQueryEscape1Parser(params, part), input)
  }
}

struct UriQueryEscape2Parser: Iteratee {
  let params: [(String?, String)]
  let part: String
  let c1: UnicodeScalar

  init(_ params: [(String?, String)], _ part: String, _ c1: UnicodeScalar) {
    self.params = params
    self.part = part
    self.c1 = c1
  }

  func feed(input: IterateeInput) -> IterateeOutput {
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

struct UriQueryValueParser: Iteratee {
  let params: [(String?, String)]
  let key: String
  let value: String

  init(_ params: [(String?, String)], _ key: String, _ value: String = "") {
    self.params = params
    self.key = key
    self.value = value
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
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

struct UriQueryValueEscape1Parser: Iteratee {
  let params: [(String?, String)]
  let key: String
  let value: String

  init(_ params: [(String?, String)], _ key: String, _ value: String) {
    self.params = params
    self.key = key
    self.value = value
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    if let c1 = input.head where isHexChar(c1) {
      return cont(UriQueryValueEscape2Parser(params, key, value, c1), input.tail)
    } else if !input.isEmpty || input.isDone {
      return expected("hex digit", input)
    }
    return cont(UriQueryValueEscape1Parser(params, key, value), input)
  }
}

struct UriQueryValueEscape2Parser: Iteratee {
  let params: [(String?, String)]
  let key: String
  let value: String
  let c1: UnicodeScalar

  init(_ params: [(String?, String)], _ key: String, _ value: String, _ c1: UnicodeScalar) {
    self.params = params
    self.key = key
    self.value = value
    self.c1 = c1
  }

  func feed(input: IterateeInput) -> IterateeOutput {
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
  let fragment: String

  init(_ fragment: String = "") {
    self.fragment = fragment
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
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

struct UriFragmentEscape1Parser: Iteratee {
  let fragment: String

  init(_ fragment: String) {
    self.fragment = fragment
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    if let c1 = input.head where isHexChar(c1) {
      return cont(UriFragmentEscape2Parser(fragment, c1), input.tail)
    } else if !input.isEmpty || input.isDone {
      return expected("hex digit", input)
    }
    return cont(UriFragmentEscape1Parser(fragment), input)
  }
}

struct UriFragmentEscape2Parser: Iteratee {
  let fragment: String
  let c1: UnicodeScalar

  init(_ fragment: String, _ c1: UnicodeScalar) {
    self.fragment = fragment
    self.c1 = c1
  }

  func feed(input: IterateeInput) -> IterateeOutput {
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


func isUnreservedChar(c: UnicodeScalar) -> Bool {
  return c == "-" || c == "." ||
    c >= "0" && c <= "9" ||
    c >= "A" && c <= "Z" ||
    c == "_" ||
    c >= "a" && c <= "z" ||
    c == "~"
}

func isSubDelimChar(c: UnicodeScalar) -> Bool {
  return c == "!" || c == "$" ||
    c == "&" || c == "'" ||
    c == "(" || c == ")" ||
    c == "*" || c == "+" ||
    c == "," || c == ";" ||
    c == "="
}

internal func isSchemeChar(c: UnicodeScalar) -> Bool {
  return c == "+" || c == "-" || c == "." ||
    c >= "0" && c <= "9" ||
    c >= "A" && c <= "Z" ||
    c >= "a" && c <= "z"
}

internal func isUserInfoChar(c: UnicodeScalar) -> Bool {
  return isUnreservedChar(c) || isSubDelimChar(c) || c == ":"
}

internal func isUserChar(c: UnicodeScalar) -> Bool {
  return isUnreservedChar(c) || isSubDelimChar(c)
}

internal func isHostChar(c: UnicodeScalar) -> Bool {
  return isUnreservedChar(c) || isSubDelimChar(c)
}

internal func isPathChar(c: UnicodeScalar) -> Bool {
  return isUnreservedChar(c) || isSubDelimChar(c) || c == ":" || c == "@"
}

internal func isQueryChar(c: UnicodeScalar) -> Bool {
  return isUnreservedChar(c) || isSubDelimChar(c) || c == "/" || c == ":" || c == "?" || c == "@"
}

internal func isParamChar(c: UnicodeScalar) -> Bool {
  return isUnreservedChar(c) ||
    c == "!" || c == "$" ||
    c == "'" || c == "(" ||
    c == ")" || c == "*" ||
    c == "+" || c == "," ||
    c == "/" || c == ":" ||
    c == ";" || c == "?" ||
    c == "@"
}

internal func isFragmentChar(c: UnicodeScalar) -> Bool {
  return isUnreservedChar(c) || isSubDelimChar(c) || c == "/" || c == ":" || c == "?" || c == "@"
}

internal func isAlpha(c: UnicodeScalar) -> Bool {
  return c >= "A" && c <= "Z" || c >= "a" && c <= "z"
}

func isDigit(c: UnicodeScalar) -> Bool {
  return c >= "0" && c <= "9"
}

func isHexChar(c: UnicodeScalar) -> Bool {
  return c >= "0" && c <= "9" ||
    c >= "A" && c <= "F" ||
    c >= "a" && c <= "f"
}

func toLowerCase(c: UnicodeScalar) -> UnicodeScalar {
  if c >= "A" && c <= "Z" {
    return UnicodeScalar(c.value + (UnicodeScalar("a").value - UnicodeScalar("A").value))
  } else {
    return c
  }
}

func decodeDigit(c: UnicodeScalar) -> UInt32 {
  if c >= "0" && c <= "9" {
    return c.value - UnicodeScalar("0").value
  } else {
    fatalError("invalid digit")
  }
}

func decodeHex(c: UnicodeScalar) -> UInt32 {
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
