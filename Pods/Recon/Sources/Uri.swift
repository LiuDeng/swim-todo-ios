public struct Uri: StringLiteralConvertible, CustomStringConvertible, Hashable {
  public var scheme: Scheme?
  public var authority: Authority?
  public var path: Path
  public var query: Query?
  public var fragment: Fragment?

  public init(scheme: Scheme? = nil, authority: Authority? = nil, path: Path = Path.Empty, query: Query? = nil, fragment: Fragment? = nil) {
    self.scheme = scheme
    self.authority = authority
    self.path = path
    self.query = query
    self.fragment = fragment
  }

  public init(stringLiteral string: String) {
    self = Uri.parse(string)!
  }

  public init(extendedGraphemeClusterLiteral string: String) {
    self = Uri.parse(string)!
  }

  public init(unicodeScalarLiteral string: String) {
    self = Uri.parse(string)!
  }

  public func resolve(relative: Uri) -> Uri {
    if relative.scheme != nil {
      return Uri(scheme: relative.scheme, authority: relative.authority, path: relative.path.removeDotSegments, query: relative.query, fragment: relative.fragment)
    } else if relative.authority != nil {
      return Uri(scheme: scheme, authority: relative.authority, path: relative.path.removeDotSegments, query: relative.query, fragment: relative.fragment)
    } else if relative.path.isEmpty {
      return Uri(scheme: scheme, authority: authority, path: path, query: relative.query ?? query, fragment: relative.fragment)
    } else if relative.path.isAbsolute {
      return Uri(scheme: scheme, authority: authority, path: relative.path.removeDotSegments, query: relative.query, fragment: relative.fragment)
    } else {
      return Uri(scheme: scheme, authority: authority, path: merge(relative.path).removeDotSegments, query: relative.query, fragment: relative.fragment)
    }
  }

  func merge(relative: Path) -> Path {
    if authority != nil && path.isEmpty {
      return Path.Slash(relative)
    } else if path.isEmpty {
      return relative
    } else {
      return path.merge(relative)
    }
  }

  public func unresolve(absolute: Uri) -> Uri {
    if scheme != absolute.scheme || authority != absolute.authority {
      return absolute
    } else {
      return Uri(path: path.unmerge(absolute.path), query: absolute.query, fragment: absolute.fragment)
    }
  }

  public func writeUri(inout string: String) throws {
    if let scheme = self.scheme {
      try scheme.writeUri(&string)
      string.append(":" as UnicodeScalar)
    }
    if let authority = self.authority {
      string.append("/" as UnicodeScalar)
      string.append("/" as UnicodeScalar)
      authority.writeUri(&string)
    }
    path.writeUri(&string)
    if let query = self.query {
      string.append("?" as UnicodeScalar)
      query.writeUri(&string)
    }
    if let fragment = self.fragment {
      string.append("#" as UnicodeScalar)
      fragment.writeUri(&string)
    }
  }

  public var uri: String {
    do {
      var string = ""
      try writeUri(&string)
      return string
    } catch {
      return ""
    }
  }

  public var hashValue: Int {
    var hash = Int(bitPattern: 0xab94bdfd)
    if let scheme = self.scheme {
      hash = MurmurHash3.mix(hash, scheme.hashValue)
    }
    if let authority = self.authority {
      hash = MurmurHash3.mix(hash, authority.hashValue)
    }
    hash = MurmurHash3.mix(hash, path.hashValue)
    if let query = self.query {
      hash = MurmurHash3.mix(hash, query.hashValue)
    }
    if let fragment = self.fragment {
      hash = MurmurHash3.mix(hash, fragment.hashValue)
    }
    return MurmurHash3.mash(hash)
  }

  public var description: String {
    return uri;
  }

  public static var Empty: Uri {
    return Uri(scheme: nil, authority: nil, path: Path.Empty, query: nil, fragment: nil)
  }

  public static func parse(string: String) -> Uri? {
    return UriParser().parse(string).value as? Uri
  }


  public struct Scheme: StringLiteralConvertible, CustomStringConvertible, Hashable {
    public let name: String

    public init(_ name: String) {
      self.name = name
    }

    public init(stringLiteral string: String) {
      self = Scheme.parse(string)!
    }

    public init(extendedGraphemeClusterLiteral string: String) {
      self = Scheme.parse(string)!
    }

    public init(unicodeScalarLiteral string: String) {
      self = Scheme.parse(string)!
    }

    public func writeUri(inout string: String) throws {
      try string.writeUriScheme(name)
    }

    public var hashValue: Int {
      return MurmurHash3.hash(Int(bitPattern: 0x81fd556a), name)
    }

    public var description: String {
      return name
    }

    public static func parse(string: String) -> Scheme? {
      return UriSchemeParser().parse(string).value as? Scheme
    }
  }


  public struct Authority: StringLiteralConvertible, CustomStringConvertible, Hashable {
    public var userInfo: UserInfo?
    public var host: Host
    public var port: Port?

    public init(userInfo: UserInfo? = nil, host: Host, port: Port? = nil) {
      self.userInfo = userInfo
      self.host = host
      self.port = port
    }

    public init(stringLiteral string: String) {
      self = Authority.parse(string)!
    }

    public init(extendedGraphemeClusterLiteral string: String) {
      self = Authority.parse(string)!
    }

    public init(unicodeScalarLiteral string: String) {
      self = Authority.parse(string)!
    }

    public func writeUri(inout string: String) {
      if let userInfo = self.userInfo {
        userInfo.writeUri(&string)
        string.append("@" as UnicodeScalar)
      }
      host.writeUri(&string)
      if let port = self.port {
        string.append(":" as UnicodeScalar)
        port.writeUri(&string)
      }
    }

    public var hashValue: Int {
      var hash = Int(bitPattern: 0x976e6c2d)
      if let userInfo = self.userInfo {
        hash = MurmurHash3.mix(hash, userInfo.hashValue)
      }
      hash = MurmurHash3.mix(hash, host.hashValue)
      if let port = self.port {
        hash = MurmurHash3.mix(hash, port.hashValue)
      }
      return MurmurHash3.mash(hash)
    }

    public var description: String {
      var string = ""
      writeUri(&string)
      return string
    }

    public static func parse(string: String) -> Authority? {
      return UriAuthorityParser().parse(string).value as? Authority
    }
  }


  public enum UserInfo: StringLiteralConvertible, CustomStringConvertible, Hashable {
    case Login(String, String)
    case Part(String)

    public init(_ username: String, _ password: String) {
      self = Login(username, password)
    }

    public init(_ part: String) {
      self = Part(part)
    }

    public init(stringLiteral string: String) {
      self = UserInfo.parse(string)!
    }

    public init(extendedGraphemeClusterLiteral string: String) {
      self = UserInfo.parse(string)!
    }

    public init(unicodeScalarLiteral string: String) {
      self = UserInfo.parse(string)!
    }

    public var part: String {
      switch self {
      case Login(let username, let password):
        var string = ""
        string.writeUriUser(username)
        string.append(":" as UnicodeScalar)
        string.writeUriUserInfo(password)
        return string
      case Part(let part):
        return part
      }
    }

    public func writeUri(inout string: String) {
      switch self {
      case Login(let username, let password):
        string.writeUriUser(username)
        string.append(":" as UnicodeScalar)
        string.writeUriUserInfo(password)
      case Part(let part):
        string.writeUriUserInfo(part)
      }
    }

    public var hashValue: Int {
      switch self {
      case Login(let username, let password):
        return MurmurHash3.hash(Int(bitPattern: 0x7c1c524c), username, password)
      case Part(let part):
        return MurmurHash3.hash(Int(bitPattern: 0x9a1a9b3b), part)
      }
    }

    public var description: String {
      var string = ""
      writeUri(&string)
      return string
    }

    public static func parse(string: String) -> UserInfo? {
      return UriUserInfoParser().parse(string).value as? UserInfo
    }
  }


  public enum Host: StringLiteralConvertible, CustomStringConvertible, Hashable {
    case Name(String)
    case IPv4(String)
    case IPv6(String)

    public init(stringLiteral string: String) {
      self = Host.parse(string)!
    }

    public init(extendedGraphemeClusterLiteral string: String) {
      self = Host.parse(string)!
    }

    public init(unicodeScalarLiteral string: String) {
      self = Host.parse(string)!
    }

    public func writeUri(inout string: String) {
      switch self {
      case Name(let address):
        string.writeUriHost(address)
      case IPv4(let address):
        string.writeUriHost(address)
      case IPv6(let address):
        string.append("[" as UnicodeScalar)
        string.writeUriHostLiteral(address)
        string.append("]" as UnicodeScalar)
      }
    }

    public var hashValue: Int {
      switch self {
      case Name(let address):
        return MurmurHash3.hash(Int(bitPattern: 0x376b0b92), address)
      case IPv4(let address):
        return MurmurHash3.hash(Int(bitPattern: 0x76ec1411), address)
      case IPv6(let address):
        return MurmurHash3.hash(Int(bitPattern: 0x787c6ccd), address)
      }
    }

    public var description: String {
      var string = ""
      writeUri(&string)
      return string
    }

    public static func parse(string: String) -> Host? {
      return UriHostParser().parse(string).value as? Host
    }
  }


  public struct Port: IntegerLiteralConvertible, CustomStringConvertible, Hashable {
    public let number: UInt16

    public init(_ number: UInt16) {
      self.number = number
    }

    public init(integerLiteral number: UInt16) {
      self.init(number)
    }

    public init(stringLiteral string: String) {
      self = Port.parse(string)!
    }

    public init(extendedGraphemeClusterLiteral string: String) {
      self = Port.parse(string)!
    }

    public init(unicodeScalarLiteral string: String) {
      self = Port.parse(string)!
    }

    public func writeUri(inout string: String) {
      string.writeUriPort(number)
    }

    public var hashValue: Int {
      return MurmurHash3.hash(Int(bitPattern: 0x335a7c54), number)
    }

    public var description: String {
      var string = ""
      writeUri(&string)
      return string
    }

    public static func parse(string: String) -> Port? {
      return UriPortParser().parse(string).value as? Port
    }
  }


  public indirect enum Path: SequenceType, ArrayLiteralConvertible, StringLiteralConvertible, CustomStringConvertible, Hashable {
    case Segment(String, Path)
    case Slash(Path)
    case Empty

    public init(_ segments: [String]) {
      var path = Empty
      var i = segments.count - 1
      while i >= 0 {
        let segment = segments[i]
        if segment == "/" {
          path = Slash(path)
        } else {
          path = Segment(segment, path)
        }
        i -= 1
      }
      self = path
    }

    public init(_ segments: String...) {
      self.init(segments)
    }

    public init(arrayLiteral segments: String...) {
      self.init(segments)
    }

    public init(stringLiteral string: String) {
      self = Path.parse(string)!
    }

    public init(extendedGraphemeClusterLiteral string: String) {
      self = Path.parse(string)!
    }

    public init(unicodeScalarLiteral string: String) {
      self = Path.parse(string)!
    }

    public var isAbsolute: Bool {
      switch self {
      case Slash:
        return true
      case Segment, Empty:
        return false
      }
    }

    public var isRelative: Bool {
      switch self {
      case Segment, Empty:
        return true
      case Slash:
        return false
      }
    }

    public var isEmpty: Bool {
      switch self {
      case Segment, Slash:
        return false
      case Empty:
        return true
      }
    }

    public var head: String? {
      switch self {
      case Segment(let head, _):
        return head
      case Slash:
        return "/"
      case Empty:
        return nil
      }
    }

    public var tail: Path {
      switch self {
      case Segment(_, let tail):
        return tail
      case Slash(let tail):
        return tail
      case Empty:
        fatalError("tail of empty path")
      }
    }

    public var removeDotSegments: Path {
      var path = self
      var segments = [String]()
      while let head = path.head {
        if head == "." || head == ".." {
          path = path.tail
          if !path.isEmpty {
            path = path.tail
          }
        }
        else if head == "/" {
          let rest = path.tail
          if let next = rest.head {
            if next == "." {
              path = rest.tail
              if path.isEmpty {
                path = Slash(Empty)
              }
            } else if next == ".." {
              path = rest.tail
              if path.isEmpty {
                path = Slash(Empty)
              }
              if let last = segments.popLast() where last != "/" {
                segments.popLast()
              }
            } else {
              segments.append(head)
              segments.append(next)
              path = rest.tail
            }
          } else {
            segments.append(path.head!)
            path = path.tail
          }
        } else {
          segments.append(path.head!)
          path = path.tail
        }
      }
      return Path(segments)
    }

    func merge(var path: Path) -> Path {
      var segments = [String]()
      var head = self.head!
      var tail = self.tail
      while !tail.isEmpty {
        segments.append(head)
        head = tail.head!
        tail = tail.tail
      }
      if head == "/" {
        segments.append(head)
      }
      while let head = path.head {
        segments.append(head)
        path = path.tail
      }
      return Path(segments)
    }

    func unmerge(path: Path) -> Path {
      return unmerge(self, relative: path, root: path)
    }

    func unmerge(var base: Path, var relative: Path, root: Path) -> Path {
      while true {
        if base.isEmpty {
          if !relative.isEmpty && !relative.tail.isEmpty {
            return relative.tail
          } else {
            return relative
          }
        } else if base.isRelative {
          return relative
        } else if relative.isRelative {
          return Slash(relative)
        } else {
          var a = base.tail
          var b = relative.tail
          if !a.isEmpty && b.isEmpty {
            return Slash(Empty)
          } else if a.isEmpty || b.isEmpty || a.head != b.head {
            return b
          } else {
            a = a.tail
            b = b.tail
            if !a.isEmpty && b.isEmpty {
              return root
            } else {
              base = a
              relative = b
            }
          }
        }
      }
    }

    public func writeUri(inout string: String) {
      var path = self
      while !path.isEmpty {
        switch path {
        case Segment(let head, let tail):
          string.writeUriPathSegment(head)
          path = tail
        case Slash(let tail):
          string.append("/" as UnicodeScalar)
          path = tail
        default: break
        }
      }
    }

    public mutating func append(segment: String) {
      switch self {
      case Segment(let head, var tail):
        tail.append(segment)
        self = Segment(head, tail)
      case Slash(var tail):
        tail.append(segment)
        self = Slash(tail)
      case Empty:
        if segment == "/" {
          self = Slash(Empty)
        } else {
          self = Segment(segment, Empty)
        }
      }
    }

    public mutating func prepend(segment: String) {
      if segment == "/" {
        self = Slash(self)
      } else {
        self = Segment(segment, self)
      }
    }

    public var first: String? {
      return head
    }

    public var last: String? {
      var path = self
      var last = nil as String?
      while !path.isEmpty {
        switch path {
        case Segment(let head, let tail):
          last = head
          path = tail
        case Slash(let tail):
          last = "/"
          path = tail
        default: break
        }
      }
      return last
    }

    public mutating func popFirst() -> String? {
      switch self {
      case Segment(let head, let tail):
        self = tail
        return head
      case Slash(let tail):
        self = tail
        return "/"
      default:
        return nil
      }
    }

    public mutating func popLast() -> String? {
      var segments = [String]()
      var last = nil as String?
      var path = self
      while !path.isEmpty {
        switch path {
        case Segment(let head, let tail) where tail.isEmpty:
          last = head
          path = Empty
        case Segment(let head, let tail):
          segments.append(head)
          path = tail
        case Slash(let tail) where tail.isEmpty:
          last = "/"
          path = Empty
        case Slash(let tail):
          segments.append("/")
          path = tail
        case Empty: break
        }
      }
      self = Path(segments)
      return last
    }

    public func dropFirst() -> Path {
      return tail
    }

    public func dropLast() -> Path {
      switch self {
      case Segment(_, let tail) where tail.isEmpty:
        return Empty
      case Segment(let head, var tail):
        tail = tail.dropLast()
        return Segment(head, tail)
      case Slash(let tail) where tail.isEmpty:
        return Empty
      case Slash(var tail):
        tail = tail.dropLast()
        return Slash(tail)
      case Empty:
        fatalError("dropLast of empty path")
      }
    }

    public func generate() -> PathGenerator {
      return PathGenerator(self)
    }

    public var hashValue: Int {
      var path = self
      var hash = Int(bitPattern: 0x40ea02cf)
      while let head = path.head {
        hash = MurmurHash3.mix(hash, head.hashValue)
        path = path.tail
      }
      return MurmurHash3.mash(hash)
    }

    public var description: String {
      var string = ""
      writeUri(&string)
      return string
    }

    public static func parse(string: String) -> Path? {
      return UriPathParser().parse(string).value as? Path
    }
  }

  public struct PathGenerator: GeneratorType {
    var path: Path?

    init(_ path: Path) {
      self.path = path
    }

    mutating public func next() -> String? {
      if let path = self.path {
        switch path {
        case .Segment(let head, let tail):
          self.path = tail
          return head
        case .Slash(let tail):
          self.path = tail
          return "/"
        case .Empty:
          self.path = nil
          return nil
        }
      } else {
        preconditionFailure("next already returned nil")
      }
    }
  }


  public indirect enum Query: SequenceType, DictionaryLiteralConvertible, ArrayLiteralConvertible, StringLiteralConvertible, CustomStringConvertible, Hashable {
    case Param(String, String, Query)
    case Part(String, Query)
    case Empty

    public init(_ params: [(String?, String)]) {
      var query = Empty
      var i = params.count - 1
      while i >= 0 {
        let (k, value) = params[i]
        if let key = k {
          query = Param(key, value, query)
        } else {
          query = Part(value, query)
        }
        i -= 1
      }
      self = query
    }

    public init(_ params: [(String, String)]) {
      var query = Empty
      var i = params.count - 1
      while i >= 0 {
        let (key, value) = params[i]
        query = Param(key, value, query)
        i -= 1
      }
      self = query
    }

    public init(_ params: [String]) {
      var query = Empty
      var i = params.count - 1
      while i >= 0 {
        let part = params[i]
        query = Part(part, query)
        i -= 1
      }
      self = query
    }

    public init(key: String, value: String) {
      self = Param(key, value, Empty)
    }

    public init(part: String) {
      self = Part(part, Empty)
    }

    public init(dictionaryLiteral params: (String, String)...) {
      self.init(params)
    }

    public init(arrayLiteral params: String...) {
      self.init(params)
    }

    public init(stringLiteral string: String) {
      self = Query.parse(string)!
    }

    public init(extendedGraphemeClusterLiteral string: String) {
      self = Query.parse(string)!
    }

    public init(unicodeScalarLiteral string: String) {
      self = Query.parse(string)!
    }

    public var isEmpty: Bool {
      switch self {
      case Param, Part:
        return false
      case Empty:
        return true
      }
    }

    public var head: (String?, String)? {
      switch self {
      case Param(let key, let value, _):
        return (key, value)
      case Part(let part, _):
        return (nil, part)
      case Empty:
        return nil
      }
    }

    public var headParam: (String, String)? {
      switch self {
      case Param(let key, let value, _):
        return (key, value)
      case Part, Empty:
        return nil
      }
    }

    public var headPart: String? {
      switch self {
      case Part(let part, _):
        return part
      case Param, Empty:
        return nil
      }
    }

    public var tail: Query {
      switch self {
      case Param(_, _, let tail):
        return tail
      case Part(_, let tail):
        return tail
      case Empty:
        fatalError("tail of empty query")
      }
    }

    public func contains(key: String) -> Bool {
      var query = self
      while !query.isEmpty {
        switch query {
        case Param(let k, _, let tail):
          if key == k {
            return true
          }
          query = tail
        case Part(_, let tail):
          query = tail
        default: break
        }
      }
      return false
    }

    public subscript(key: String) -> String? {
      var query = self
      while !query.isEmpty {
        switch query {
        case Param(let k, let value, let tail):
          if key == k {
            return value
          }
          query = tail
        case Part(_, let tail):
          query = tail
        default: break
        }
      }
      return nil
    }

    public func writeUri(inout string: String) {
      var query = self
      var first = true
      while !query.isEmpty {
        if !first {
          string.append("&" as UnicodeScalar)
        }
        switch query {
        case Param(let key, let value, let tail):
          string.writeUriParam(key)
          string.append("=" as UnicodeScalar)
          string.writeUriParam(value)
          query = tail
        case Part(let part, let tail):
          string.writeUriQuery(part)
          query = tail
        default: break
        }
        first = false
      }
    }

    public mutating func append(key: String, _ value: String) {
      switch self {
      case Param(let k, let v, var tail):
        tail.append(key, value)
        self = Param(k, v, tail)
      case Part(let p, var tail):
        tail.append(key, value)
        self = Part(p, tail)
      case Empty:
        self = Param(key, value, Empty)
      }
    }

    public mutating func append(part: String) {
      switch self {
      case Param(let k, let v, var tail):
        tail.append(part)
        self = Param(k, v, tail)
      case Part(let p, var tail):
        tail.append(part)
        self = Part(p, tail)
      case Empty:
        self = Part(part, Empty)
      }
    }

    public mutating func prepend(key: String, _ value: String) {
      self = Param(key, value, self)
    }

    public mutating func prepend(part: String) {
      self = Part(part, self)
    }

    public var first: (String?, String)? {
      return head
    }

    public var last: (String?, String)? {
      var query = self
      var last = nil as (String?, String)?
      while !query.isEmpty {
        switch query {
        case Param(let key, let value, let tail):
          last = (key, value)
          query = tail
        case Part(let part, let tail):
          last = (nil, part)
          query = tail
        default: break
        }
      }
      return last
    }

    public mutating func popFirst() -> (String?, String)? {
      switch self {
      case Param(let key, let value, let tail):
        self = tail
        return (key, value)
      case Part(let part, let tail):
        self = tail
        return (nil, part)
      default:
        return nil
      }
    }

    public mutating func popLast() -> (String?, String)? {
      var params = [(String?, String)]()
      var last = nil as (String?, String)?
      var query = self
      while !query.isEmpty {
        switch query {
        case Param(let key, let value, let tail) where tail.isEmpty:
          last = (key, value)
          query = Empty
        case Param(let key, let value, let tail):
          params.append((key, value))
          query = tail
        case Part(let part, let tail) where tail.isEmpty:
          last = (nil, part)
          query = Empty
        case Part(let part, let tail):
          params.append((nil, part))
          query = tail
        case Empty: break
        }
      }
      self = Query(params)
      return last
    }

    public func dropFirst() -> Query {
      return tail
    }

    public func dropLast() -> Query {
      switch self {
      case Param(_, _, let tail) where tail.isEmpty:
        return Empty
      case Param(let key, let value, var tail):
        tail = tail.dropLast()
        return Param(key, value, tail)
      case Part(_, let tail) where tail.isEmpty:
        return Empty
      case Part(let part, var tail):
        tail = tail.dropLast()
        return Part(part, tail)
      case Empty:
        fatalError("dropLast of empty path")
      }
    }

    public func generate() -> QueryGenerator {
      return QueryGenerator(self)
    }

    public var hashValue: Int {
      var query = self
      var hash = Int(bitPattern: 0xb5ef74ea)
      while !query.isEmpty {
        switch query {
        case Param(let key, let value, let tail):
          hash = MurmurHash3.mix(MurmurHash3.mix(hash, key.hashValue), value.hashValue)
          query = tail
        case Part(let part, let tail):
          hash = MurmurHash3.mix(hash, part.hashValue)
          query = tail
        default: break
        }
      }
      return MurmurHash3.mash(hash)
    }

    public var description: String {
      var string = ""
      writeUri(&string)
      return string
    }

    public static func parse(string: String) -> Query? {
      return UriQueryParser().parse(string).value as? Query
    }
  }

  public struct QueryGenerator: GeneratorType {
    var query: Query?

    init(_ query: Query) {
      self.query = query
    }

    mutating public func next() -> (String?, String)? {
      if let query = self.query {
        switch query {
        case .Param(let key, let value, let tail):
          self.query = tail
          return (key, value)
        case .Part(let part, let tail):
          self.query = tail
          return (nil, part)
        case .Empty:
          self.query = nil
          return nil
        }
      } else {
        preconditionFailure("next already returned nil")
      }
    }
  }


  public struct Fragment: StringLiteralConvertible, CustomStringConvertible, Hashable {
    public let value: String

    public init(_ value: String) {
      self.value = value
    }

    public init(stringLiteral string: String) {
      self = Fragment.parse(string)!
    }

    public init(extendedGraphemeClusterLiteral string: String) {
      self = Fragment.parse(string)!
    }

    public init(unicodeScalarLiteral string: String) {
      self = Fragment.parse(string)!
    }

    public func writeUri(inout string: String) {
      string.writeUriFragment(value)
    }

    public var hashValue: Int {
      return MurmurHash3.hash(Int(bitPattern: 0x401e1016), value)
    }

    public var description: String {
      var string = ""
      writeUri(&string)
      return string
    }

    public static func parse(string: String) -> Fragment? {
      return UriFragmentParser().parse(string).value as? Fragment
    }
  }


  public enum SerializationError: ErrorType {
    case InvalidScheme
  }
}


public func == (lhs: Uri, rhs: Uri) -> Bool {
  return lhs.scheme == rhs.scheme &&
    lhs.authority == rhs.authority &&
    lhs.path == rhs.path &&
    lhs.query == rhs.query &&
    lhs.fragment == rhs.fragment
}

public func == (lhs: Uri.Scheme, rhs: Uri.Scheme) -> Bool {
  return lhs.name == rhs.name
}

public func == (lhs: Uri.Authority, rhs: Uri.Authority) -> Bool {
  return lhs.userInfo == rhs.userInfo &&
    lhs.host == rhs.host &&
    lhs.port == rhs.port
}

public func == (lhs: Uri.UserInfo, rhs: Uri.UserInfo) -> Bool {
  switch (lhs, rhs) {
  case (.Login(let username1, let password1), .Login(let username2, let password2)):
    return username1 == username2 && password1 == password2
  case (.Part(let part1), .Part(let part2)):
    return part1 == part2
  default:
    return false
  }
}

public func == (lhs: Uri.Host, rhs: Uri.Host) -> Bool {
  switch (lhs, rhs) {
  case (.Name(let address1), .Name(let address2)):
    return address1 == address2
  case (.IPv4(let address1), .IPv4(let address2)):
    return address1 == address2
  case (.IPv6(let address1), .IPv6(let address2)):
    return address1 == address2
  default:
    return false
  }
}

public func == (lhs: Uri.Port, rhs: Uri.Port) -> Bool {
  return lhs.number == rhs.number
}

public func == (lhs: Uri.Path, rhs: Uri.Path) -> Bool {
  var xs = lhs
  var ys = rhs
  while let x = xs.head, let y = ys.head {
    if x != y {
      return false
    }
    xs = xs.tail
    ys = ys.tail
  }
  return xs.isEmpty && ys.isEmpty
}

public func == (lhs: Uri.Query, rhs: Uri.Query) -> Bool {
  var xs = lhs
  var ys = rhs
  while !xs.isEmpty && !ys.isEmpty {
    switch (xs, ys) {
    case (.Param(let key1, let value1, let tail1), .Param(let key2, let value2, let tail2)):
      if key1 != key2 || value1 != value2 {
        return false
      }
      xs = tail1
      ys = tail2
    case (.Part(let part1, let tail1), .Part(let part2, let tail2)):
      if part1 != part2 {
        return false
      }
      xs = tail1
      ys = tail2
    default:
      return false
    }
  }
  return xs.isEmpty && ys.isEmpty
}

public func == (lhs: Uri.Fragment, rhs: Uri.Fragment) -> Bool {
  return lhs.value == rhs.value
}
