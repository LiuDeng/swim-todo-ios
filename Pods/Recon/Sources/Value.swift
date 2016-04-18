#if os(OSX) || os(iOS) || os(tvOS) || os(watchOS)
import Foundation
#endif

public typealias ReconValue = Value

public enum Value: ArrayLiteralConvertible, StringLiteralConvertible, FloatLiteralConvertible, IntegerLiteralConvertible, BooleanLiteralConvertible, CustomStringConvertible, Comparable, Hashable {
  case Record(ReconRecord)
  case Text(String)
  case Data(ReconData)
  case Number(Double)
  case Extant
  case Absent

  public init(arrayLiteral items: Item...) {
    self = Record(ReconRecord(items))
  }

  public init(stringLiteral value: String) {
    self = Text(value)
  }

  public init(extendedGraphemeClusterLiteral value: Character) {
    self = Text(String(value))
  }

  public init(unicodeScalarLiteral value: UnicodeScalar) {
    self = Text(String(value))
  }

  public init(floatLiteral value: Double) {
    self = Number(value)
  }

  public init(integerLiteral value: Int) {
    self = Number(Double(value))
  }

  public init(booleanLiteral value: Bool) {
    self = value ? Value.True : Value.False
  }

  public init(_ items: [Item]) {
    self = Record(ReconRecord(items))
  }

  public init(_ items: Item...) {
    self = Record(ReconRecord(items))
  }

  public init(_ value: ReconRecord) {
    self = Record(value)
  }

  public init(_ value: String) {
    self = Text(value)
  }

  public init(_ value: ReconData) {
    self = Data(value)
  }

  public init(base64 string: String) {
    self = Data(ReconData(base64: string)!)
  }

  private init(extant: Bool) {
    self = (extant ? .Extant : .Absent)
  }

#if os(OSX) || os(iOS) || os(tvOS) || os(watchOS)
  public init(data: NSData) {
    self = Data(ReconData(data: data))
  }
#endif

  public init(_ value: Double) {
    self = Number(value)
  }

  public init(_ value: Int) {
    self = Number(Double(value))
  }

  public init(_ value: Uri) {
    self = Text(value.uri)
  }

  /**
   Convert JSON-ish objects to ReconValue instances.

   This has similar restrictions to NSJSONSerialization, but expanded to
   allow for Swift native types:

   - Top level object is an `[AnyObject]` or `[String: AnyObject]`.
   - All objects are `Bool`, `Int`, `Double`, `String`, `NSNumber`,
   `[AnyObject]`, `[String: AnyObject]`, or `NSNull`.

   Keys in dictionaries are sorted before being added to the corresponding
   ReconRecord, so that the results are reproducible.
   */
  public init(json: AnyObject) {
    // Note that because json is AnyObject, the Swift native Bool, Int,
    // and Double types have been boxed.  This means that if we use
    // "json is Bool" and similar, we get the wrong answer because
    // all three native types when boxed will return true to the "is Bool"
    // query.  For this reason, we check the dynamicType.
    //
    // This is obviously relying on an internal detail of the Swift runtime,
    // but it's working around what is arguably a bug in Swift.
    if String(json.dynamicType) == "__NSCFBoolean" {
      let bool = json as! Bool
      self.init(booleanLiteral: bool)
    }
    else if String(json.dynamicType) == "__NSCFNumber" {
      let val = json as! Double
      self.init(val)
    }
    else if let str = json as? String {
      self.init(str)
    }
    else if let num = json as? NSNumber {
      self.init(num.doubleValue)
    }
    else if json is NSNull {
      self.init(extant: false)
    }
    else {
      self.init(ReconRecord(json: json))
    }
  }

  public var isDefined: Bool {
    return self != Absent
  }

  public var isRecord: Bool {
    if case Record = self {
      return true
    } else {
      return false
    }
  }

  public var isText: Bool {
    if case Text = self {
      return true
    } else {
      return false
    }
  }

  public var isData: Bool {
    if case Data = self {
      return true
    } else {
      return false
    }
  }

  public var isNumber: Bool {
    if case Number = self {
      return true
    } else {
      return false
    }
  }

  public var isExtant: Bool {
    return self == Extant
  }

  public var isAbsent: Bool {
    return self == Absent
  }

  public var record: ReconRecord? {
    if case Record(let value) = self {
      return value
    } else {
      return nil
    }
  }

  public var json: AnyObject {
    switch self {
    case .Absent:
      return NSNull()

    case .Number(let val):
      return val

    case .Record(let record):
      return record.json

    case .Text(let str):
      return str

    default:
      preconditionFailure("Cannot convert ReconValue to JSON object: \(self)")
    }
  }

  public var text: String? {
    if case Text(let value) = self {
      return value
    } else {
      return nil
    }
  }

  public var data: ReconData? {
    if case Data(let value) = self {
      return value
    } else {
      return nil
    }
  }

  public var number: Double? {
    if case Number(let value) = self {
      return value
    } else {
      return nil
    }
  }

  public var integer: Int? {
    if case Number(let value) = self {
      return Int(value)
    } else {
      return nil
    }
  }

  public var uri: Uri? {
    if let string = text {
      return Uri(string)
    } else {
      return nil
    }
  }

  public var tag: String? {
    if let head = record?.first, case .Field(.Attr(let key, _)) = head {
      return key
    } else {
      return nil
    }
  }

  public var first: Item {
    switch self {
    case Record(let value):
      return value.first ?? Item.Absent
    default:
      return Item.Absent
    }
  }

  public var last: Item {
    switch self {
    case Record(let value):
      return value.last ?? Item.Absent
    default:
      return Item.Absent
    }
  }

  public subscript(index: Int) -> Item {
    get {
      switch self {
      case Record(let value) where 0 <= index && index < value.count:
        return value[index] ?? Item.Absent
      default:
        return Item.Absent
      }
    }
  }

  public subscript(key: Value) -> Value {
    switch self {
    case Record(let value):
      return value[key] ?? Value.Absent
    default:
      return Value.Absent
    }
  }

  public mutating func popFirst() -> Item? {
    switch self {
    case Record(let value):
      let first = value.popFirst()
      self = Record(value)
      return first
    default:
      return Item.Absent
    }
  }

  public mutating func popLast() -> Item? {
    switch self {
    case Record(let value):
      let last = value.popLast()
      self = Record(value)
      return last
    default:
      return Item.Absent
    }
  }

  public func dropFirst() -> Value {
    switch self {
    case Record(let value) where !value.isEmpty:
      return Record(value.dropFirst())
    default:
      return Value.Absent
    }
  }

  public func dropLast() -> Value {
    switch self {
    case Record(let value) where !value.isEmpty:
      return Record(value.dropLast())
    default:
      return Value.Absent
    }
  }

  public subscript(key: String) -> Value {
    switch self {
    case Record(let value):
      return value[key] ?? Value.Absent
    default:
      return Value.Absent
    }
  }

  public func writeRecon(inout string: String) {
    switch self {
    case Record(let value):
      value.writeRecon(&string)
    case Text(let value):
      value.writeRecon(&string)
    case Data(let value):
      value.writeRecon(&string)
    case Number(let value):
      value.writeRecon(&string)
    default:
      break
    }
  }

  public func writeReconBlock(inout string: String) {
    switch self {
    case Record(let value):
      value.writeReconBlock(&string)
    default:
      writeRecon(&string)
    }
  }

  public var recon: String {
    switch self {
    case Record(let value):
      return value.recon
    case Text(let value):
      return value.recon
    case Data(let value):
      return value.recon
    case Number(let value):
      return value.recon
    default:
      return ""
    }
  }

  public var reconBlock: String {
    switch self {
    case Record(let value):
      return value.reconBlock
    default:
      return recon
    }
  }

  public var description: String {
    return recon
  }

  public var hashValue: Int {
    switch self {
    case Record(let value):
      return value.hashValue
    case Text(let value):
      return value.hashValue
    case Data(let value):
      return value.hashValue
    case Number(let value):
      return value.hashValue
    case Extant:
      return Int(bitPattern: 0x8e02616a)
    case Absent:
      return Int(bitPattern: 0xd35f02e5)
    }
  }

  public static var True: Value {
    return Text("true")
  }

  public static var False: Value {
    return Text("false")
  }
}

public func == (lhs: Value, rhs: Value) -> Bool {
  switch (lhs, rhs) {
  case (.Record(let x), .Record(let y)):
    return x == y
  case (.Text(let x), .Text(let y)):
    return x == y
  case (.Data(let x), .Data(let y)):
    return x == y
  case (.Number(let x), .Number(let y)):
    return x == y
  case (.Extant, .Extant):
    return true
  case (.Absent, .Absent):
    return true
  default:
    return false
  }
}

public func < (lhs: Value, rhs: Value) -> Bool {
  switch lhs {
  case .Record(let x):
    switch rhs {
    case .Record(let y):
      return x < y
    case .Data, .Text, .Number, .Extant, .Absent:
      return true
    }
  case .Data(let x):
    switch rhs {
    case .Data(let y):
      return x < y
    case .Text, .Number, .Extant, .Absent:
      return true
    default:
      return false
    }
  case .Text(let x):
    switch rhs {
    case .Text(let y):
      return x < y
    case .Number, .Extant, .Absent:
      return true
    default:
      return false
    }
  case .Number(let x):
    switch rhs {
    case .Number(let y):
      return x < y
    case .Extant, .Absent:
      return true
    default:
      return false
    }
  case .Extant:
    switch rhs {
    case .Absent:
      return true
    default:
      return false
    }
  case .Absent:
    return false
  }
}
