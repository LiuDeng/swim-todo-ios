#if os(OSX) || os(iOS) || os(tvOS) || os(watchOS)
import Foundation
#endif

public enum Item: ArrayLiteralConvertible, StringLiteralConvertible, FloatLiteralConvertible, IntegerLiteralConvertible, BooleanLiteralConvertible, CustomStringConvertible, Comparable, Hashable {
  case Field(ReconField)
  case Value(ReconValue)

  public init(arrayLiteral items: Item...) {
    self = Value(ReconValue.Record(ReconRecord(items)))
  }

  public init(stringLiteral value: String) {
    self = Value(ReconValue.Text(value))
  }

  public init(extendedGraphemeClusterLiteral value: Character) {
    self = Value(ReconValue.Text(String(value)))
  }

  public init(unicodeScalarLiteral value: UnicodeScalar) {
    self = Value(ReconValue.Text(String(value)))
  }

  public init(floatLiteral value: Double) {
    self = Value(ReconValue.Number(value))
  }

  public init(integerLiteral value: Int) {
    self = Value(ReconValue.Number(Double(value)))
  }

  public init(booleanLiteral value: Bool) {
    self = Value(value ? ReconValue.True : ReconValue.False)
  }

  public init(_ items: Item...) {
    self = Value(ReconValue(items))
  }

  public init(_ items: [Item]) {
    self = Value(ReconValue(items))
  }

  public init(_ value: ReconRecord) {
    self = Value(ReconValue(value))
  }

  public init(_ value: String) {
    self = Value(ReconValue(value))
  }

  public init(_ value: ReconData) {
    self = Value(ReconValue(value))
  }

  public init(base64 string: String) {
    self = Value(ReconValue(base64: string))
  }

#if os(OSX) || os(iOS) || os(tvOS) || os(watchOS)
  public init(data: NSData) {
    self = Value(ReconValue(data: data))
  }
#endif

  public init(_ value: Double) {
    self = Value(ReconValue(value))
  }

  public init(_ value: Uri) {
    self = Value(ReconValue(value))
  }

  public var isDefined: Bool {
    if case Value(let value) = self {
      return value.isDefined
    } else {
      return true
    }
  }

  public var isField: Bool {
    if case Field = self {
      return true
    } else {
      return false
    }
  }

  public var isAttr: Bool {
    if case Field(let field) = self {
      return field.isAttr
    } else {
      return false
    }
  }

  public var isSlot: Bool {
    if case Field(let field) = self {
      return field.isSlot
    } else {
      return false
    }
  }

  public var isValue: Bool {
    if case Value = self {
      return true
    } else {
      return false
    }
  }

  public var isRecord: Bool {
    if case Value(let value) = self {
      return value.isRecord
    } else {
      return false
    }
  }

  public var isText: Bool {
    if case Value(let value) = self {
      return value.isText
    } else {
      return false
    }
  }

  public var isData: Bool {
    if case Value(let value) = self {
      return value.isData
    } else {
      return false
    }
  }

  public var isNumber: Bool {
    if case Value(let value) = self {
      return value.isNumber
    } else {
      return false
    }
  }

  public var isExtant: Bool {
    if case Value(let value) = self {
      return value.isExtant
    } else {
      return false
    }
  }

  public var isAbsent: Bool {
    if case Value(let value) = self {
      return value.isAbsent
    } else {
      return false
    }
  }

  public var key: ReconValue? {
    if case Field(let field) = self {
      return field.key
    } else {
      return nil
    }
  }

  public var value: ReconValue {
    switch self {
    case Field(let field):
      return field.value
    case Value(let value):
      return value
    }
  }

  public var record: Record? {
    if case Value(let value) = self {
      return value.record
    } else {
      return nil
    }
  }

  public var text: String? {
    if case Value(let value) = self {
      return value.text
    } else {
      return nil
    }
  }

  public var data: Data? {
    if case Value(let value) = self {
      return value.data
    } else {
      return nil
    }
  }

  public var number: Double? {
    if case Value(let value) = self {
      return value.number
    } else {
      return nil
    }
  }

  public var integer: Int? {
    if case Value(let value) = self {
      return value.integer
    } else {
      return nil
    }
  }

  public var uri: Uri? {
    if let string = text {
      return Uri.parse(string)
    } else {
      return nil
    }
  }

  public var first: Item {
    switch self {
    case Value(let value):
      return value.first
    default:
      return Item.Absent
    }
  }

  public var last: Item {
    switch self {
    case Value(let value):
      return value.last
    default:
      return Item.Absent
    }
  }

  public subscript(index: Int) -> Item {
    switch self {
    case Value(let value):
      return value[index]
    default:
      return Item.Absent
    }
  }

  public subscript(key: ReconValue) -> ReconValue {
    switch self {
    case Value(let value):
      return value[key]
    default:
      return ReconValue.Absent
    }
  }

  public subscript(key: String) -> ReconValue {
    switch self {
    case Value(let value):
      return value[key]
    default:
      return ReconValue.Absent
    }
  }

  public mutating func popFirst() -> Item? {
    switch self {
    case Value(var value):
      let first = value.popFirst()
      self = Value(value)
      return first
    default:
      return Item.Absent
    }
  }

  public mutating func popLast() -> Item? {
    switch self {
    case Value(var value):
      let last = value.popLast()
      self = Value(value)
      return last
    default:
      return Item.Absent
    }
  }

  public func dropFirst() -> Item {
    switch self {
    case Value(let value):
      return Value(value.dropFirst())
    default:
      return Item.Absent
    }
  }

  public func dropLast() -> Item {
    switch self {
    case Value(let value):
      return Value(value.dropLast())
    default:
      return Item.Absent
    }
  }

  public func writeRecon(inout string: String) {
    switch self {
    case Field(let field):
      field.writeRecon(&string)
    case Value(let value):
      value.writeRecon(&string)
    }
  }

  public func writeReconBlock(inout string: String) {
    switch self {
    case Field(let field):
      field.writeRecon(&string)
    case Value(let value):
      value.writeReconBlock(&string)
    }
  }

  public var recon: String {
    switch self {
    case Field(let field):
      return field.recon
    case Value(let value):
      return value.recon
    }
  }

  public var reconBlock: String {
    switch self {
    case Field(let field):
      return field.recon
    case Value(let value):
      return value.reconBlock
    }
  }

  public var description: String {
    return recon
  }

  public var hashValue: Int {
    switch self {
    case Field(let field):
      return field.hashValue
    case Value(let value):
      return value.hashValue
    }
  }

  public static func Attr(key: String, _ value: ReconValue) -> Item {
    return Field(ReconField.Attr(key, value))
  }

  public static func Attr(key: String) -> Item {
    return Field(ReconField.Attr(key, ReconValue.Extant))
  }

  public static func Slot(key: ReconValue, _ value: ReconValue) -> Item {
    return Field(ReconField.Slot(key, value))
  }

  public static func Slot(key: ReconValue) -> Item {
    return Field(ReconField.Slot(key, ReconValue.Extant))
  }

  public static func Record(value: ReconRecord) -> Item {
    return Value(ReconValue.Record(value))
  }

  public static func Record(items: [Item]) -> Item {
    return Value(ReconValue.Record(ReconRecord(items)))
  }

  public static func Record(items: Item...) -> Item {
    return Value(ReconValue.Record(ReconRecord(items)))
  }

  public static func Record(item: Item) -> Item {
    return Value(ReconValue.Record(ReconRecord(item)))
  }

  public static func Text(value: String) -> Item {
    return Value(ReconValue.Text(value))
  }

  public static func Data(value: ReconData) -> Item {
    return Value(ReconValue.Data(value))
  }

  public static func Data(base64 string: String) -> Item {
    return Value(ReconValue.Data(ReconData(base64: string)!))
  }

  public static func Number(value: Double) -> Item {
    return Value(ReconValue.Number(value))
  }

  public static var True: Item {
    return Value(ReconValue.True)
  }

  public static var False: Item {
    return Value(ReconValue.False)
  }

  public static var Extant: Item {
    return Value(ReconValue.Extant)
  }

  public static var Absent: Item {
    return Value(ReconValue.Absent)
  }
}

public func == (lhs: Item, rhs: Item) -> Bool {
  switch (lhs, rhs) {
  case (.Field(let x), .Field(let y)):
    return x == y
  case (.Value(let x), .Value(let y)):
    return x == y
  default:
    return false
  }
}

public func < (lhs: Item, rhs: Item) -> Bool {
  switch lhs {
  case .Field(let x):
    switch rhs {
    case .Field(let y):
      return x < y
    case .Value:
      return true
    }
  case .Value(let x):
    switch rhs {
    case .Value(let y):
      return x < y
    default:
      return false
    }
  }
}
