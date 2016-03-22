public typealias ReconField = Field

public func Attr(key: String, _ value: Value) -> Item {
  return Item.Field(Field.Attr(key, value))
}

public func Attr(key: String) -> Item {
  return Item.Field(Field.Attr(key, Value.Extant))
}

public func Slot(key: Value, _ value: Value) -> Item {
  return Item.Field(Field.Slot(key, value))
}

public func Slot(key: Value) -> Item {
  return Item.Field(Field.Slot(key, Value.Extant))
}

public enum Field: CustomStringConvertible, Comparable, Hashable {
  case Attr(String, Value)
  case Slot(Value, Value)

  public var isAttr: Bool {
    if case Attr = self {
      return true
    } else {
      return false
    }
  }

  public var isSlot: Bool {
    if case Slot = self {
      return true
    } else {
      return false
    }
  }

  var key: Value {
    switch self {
    case Attr(let key, _):
      return Value.Text(key)
    case Slot(let key, _):
      return key
    }
  }

  var value: Value {
    switch self {
    case Attr(_, let value):
      return value
    case Slot(_, let value):
      return value
    }
  }

  func writeReconAttr(key: String, _ value: Value, inout _ string: String) {
    string.append(UnicodeScalar("@"))
    key.writeReconIdent(&string)
    if value != Value.Extant {
      string.append(UnicodeScalar("("))
      value.writeReconBlock(&string)
      string.append(UnicodeScalar(")"))
    }
  }

  func writeReconSlot(key: Value, _ value: Value, inout _ string: String) {
    key.writeRecon(&string)
    string.append(UnicodeScalar(":"))
    if value != Value.Extant {
      value.writeRecon(&string)
    }
  }

  public func writeRecon(inout string: String) {
    switch self {
    case Attr(let key, let value):
      writeReconAttr(key, value, &string)
    case Slot(let key, let value):
      writeReconSlot(key, value, &string)
    }
  }

  public var recon: String {
    var string = ""
    writeRecon(&string)
    return string
  }

  public var description: String {
    return recon
  }

  public var hashValue: Int {
    switch self {
    case Attr(let key, let value):
      return MurmurHash3.hash(Int(bitPattern: 0x8b9cf328), key, value)
    case Slot(let key, let value):
      return MurmurHash3.hash(Int(bitPattern: 0x543c0c9b), key, value)
    }
  }
}

public func == (lhs: Field, rhs: Field) -> Bool {
  switch (lhs, rhs) {
  case (.Attr(let k1, let v1), .Attr(let k2, let v2)):
    return k1 == k2 && v1 == v2
  case (.Slot(let k1, let v1), .Slot(let k2, let v2)):
    return k1 == k2 && v1 == v2
  default:
    return false
  }
}

public func < (lhs: Field, rhs: Field) -> Bool {
  switch lhs {
  case .Attr(let k1, let v1):
    switch rhs {
    case .Attr(let k2, let v2):
      if k1 != k2 {
        return k1 < k2
      } else {
        return v1 < v2
      }
    case .Slot:
      return true
    }
  case .Slot(let k1, let v1):
    switch rhs {
    case .Slot(let k2, let v2):
      if k1 != k2 {
        return k1 < k2
      } else {
        return v1 < v2
      }
    default:
      return false
    }
  }
}
