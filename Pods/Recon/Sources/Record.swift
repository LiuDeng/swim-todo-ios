public typealias ReconRecord = Record

public struct Record: CollectionType, ArrayLiteralConvertible, CustomStringConvertible, Comparable, Hashable {
  public typealias Element = Item
  public typealias Index = Int

  private static let indexThreshold: Int = 8

  var items: [Item]
  var fields: [Value: Value]?

  init(items: [Item], fields: [Value: Value]?) {
    self.items = items
    self.fields = fields
  }

  public init(_ items: [Item]) {
    self.init(items: items, fields: nil)
  }

  public init(_ items: ArraySlice<Item>) {
    self.init(items: Array(items), fields: nil)
    reindex()
  }

  public init(arrayLiteral items: Item...) {
    self.init(items: items, fields: nil)
    reindex()
  }

  public init(_ items: Item...) {
    self.init(items: items, fields: nil)
    reindex()
  }

  public init(_ item: Item) {
    self.init(items: [item], fields: nil)
  }

  public init() {
    self.init(items: [], fields: nil)
  }

  /**
   Convert JSON-ish objects to ReconRecord instances.

   This has similar restrictions to NSJSONSerialization, but expanded to
   allow for Swift native types:

   - Top level object is an `[AnyObject]` or `[String: AnyObject]`.
   - All objects are `Bool`, `Int`, `Double`, `String`, `NSNumber`,
     `[AnyObject]`, `[String: AnyObject]`, or `NSNull`.

   Keys in dictionaries are sorted before being added to the corresponding
   ReconRecord, so that the results are reproducible.
   */
  public init(json: AnyObject) {
    if let arr = json as? [AnyObject] {
      let newItems = arr.map { Item(reconValue: Value(json: $0)) }
      self.init(newItems)
    }
    else if let dict = json as? [String: AnyObject] {
      let keys = dict.keys.sort()
      let newItems = keys.map { Item.Attr($0, Value(json: dict[$0]!)) }
      self.init(newItems)
    }
    else {
      preconditionFailure()
    }
  }

  public var isEmpty: Bool {
    return items.isEmpty
  }

  public var startIndex: Int {
    return items.startIndex
  }

  public var endIndex: Int {
    return items.endIndex
  }

  public var count: Int {
    return items.count
  }

  public var first: Item? {
    return items.first
  }

  public var last: Item? {
    return items.last
  }

  public func contains(key: Value) -> Bool {
    if let fields = self.fields {
      return fields.indexForKey(key) != nil
    } else {
      return items.contains { item in
        if case .Field(let field) = item {
          return key == field.key
        } else {
          return false
        }
      }
    }
  }

  public subscript(index: Int) -> Item {
    get {
      return items[index]
    }
    set(item) {
      if case .Field(let field) = items[index] {
        fields?.removeValueForKey(field.key)
      }
      items[index] = item
      if case .Field(let field) = item {
        fields?[field.key] = field.value
      }
    }
  }

  public subscript(key: Value) -> Value {
    get {
      if let fields = self.fields {
        return fields[key] ?? Value.Absent
      } else {
        for item in items {
          if case .Field(let field) = item where key == field.key {
            return field.value
          }
        }
        return Value.Absent
      }
    }
    set(value) {
      fields?[key] = value
      for i in 0 ..< items.count {
        let item = items[i]
        if item.key == key {
          switch item {
          case .Field(.Slot):
            items[i] = Item.Slot(key, value)
          case .Field(.Attr):
            items[i] = Item.Attr(key.text!, value)
          default: break
          }
          return
        }
      }
      items.append(Item.Slot(key, value))
    }
  }

  public subscript(key: String) -> Value {
    get {
      return self[Value.Text(key)]
    }
    set(item) {
      self[Value.Text(key)] = item
    }
  }

  public mutating func append(item: Item) {
    items.append(item)
    if case .Field(let field) = item {
      if var fields = self.fields {
        fields.updateValue(field.value, forKey: field.key)
        self.fields = fields
      } else {
        reindex()
      }
    }
  }

  public mutating func appendContentsOf<C: CollectionType where C.Generator.Element == Element>(newItems: C) {
    items.appendContentsOf(newItems)
    reindex()
  }

  public mutating func appendContentsOf<S: SequenceType where S.Generator.Element == Element>(newItems: S) {
    items.appendContentsOf(newItems)
    reindex()
  }

  public mutating func removeValueForKey(key: Value) {
    fields?.removeValueForKey(key)
    for i in 0 ..< items.count {
      let item = items[i]
      if item.key == key {
        items.removeAtIndex(i)
        return
      }
    }
  }

  public mutating func popFirst() -> Item? {
    let first = items.first
    self = Record(items.dropFirst())
    return first
  }

  public mutating func popLast() -> Item? {
    let last = items.last
    self = Record(items.dropLast())
    return last
  }

  public func dropFirst() -> Record {
    return Record(items.dropFirst())
  }

  public func dropLast() -> Record {
    return Record(items.dropLast())
  }

  var isBlockSafe: Bool {
    let n = items.endIndex
    var i = items.startIndex
    while i < n {
      if items[i].isAttr {
        return false
      }
      i += 1
    }
    return true
  }

  var isMarkupSafe: Bool {
    let n = items.endIndex
    var i = items.startIndex
    if i < n && items[i].isAttr {
      i += 1
      while i < n {
        if items[i].isAttr {
          return false
        }
        i += 1
      }
      return true
    }
    return false
  }

  public func writeReconItem(item: Item, inout _ string: String) {
    if case .Field(let field) = item {
      field.key.writeRecon(&string)
      string.append(UnicodeScalar(":"))
      if field.value != Value.Extant {
        field.value.writeRecon(&string)
      }
    } else {
      item.writeRecon(&string)
    }
  }

  public func writeReconRecord(inout string: String, inBlock: Bool, inMarkup: Bool) {
    let n = items.endIndex
    var i = items.startIndex
    var inBraces = false
    var inBrackets = false
    var first = true
    while (i < n) {
      let item = items[i]
      i += 1
      if inBrackets && item.isAttr {
        if inBraces {
          string.append(UnicodeScalar("}"))
          inBraces = false
        }
        string.append(UnicodeScalar("]"))
        inBrackets = false
      }
      if item.isAttr {
        if inBraces {
          string.append(UnicodeScalar("}"))
          inBraces = false
        } else if inBrackets {
          string.append(UnicodeScalar("]"))
          inBrackets = false
        }
        item.writeRecon(&string)
        first = false
      } else if inBrackets && item.isText {
        if inBraces {
          string.append(UnicodeScalar("}"))
          inBraces = false
        }
        item.text!.writeReconMarkupText(&string)
      } else if inBraces {
        if !first {
          string.append(UnicodeScalar(","))
        } else {
          first = false
        }
        writeReconItem(item, &string)
      } else if inBrackets {
        if item.isRecord && item.record!.isMarkupSafe {
          item.record!.writeReconRecord(&string, inBlock: false, inMarkup: true)
          if i < n && items[i].isText {
            items[i].text!.writeReconMarkupText(&string)
            i += 1
          } else if i < n && items[i].isAttr {
            string.append(UnicodeScalar("{"))
            inBraces = true
            first = true
          } else {
            string.append(UnicodeScalar("]"))
            inBrackets = false
          }
        } else {
          string.append(UnicodeScalar("{"))
          item.writeRecon(&string)
          inBraces = true
          first = false
        }
      } else if item.isText && i < n && !items[i].isField && !items[i].isText {
        string.append(UnicodeScalar("["))
        item.text!.writeReconMarkupText(&string)
        inBrackets = true
      } else if inBlock && !inBraces {
        if !first {
          string.append(UnicodeScalar(","))
        } else {
          first = false
        }
        writeReconItem(item, &string)
      } else if inMarkup && item.isText && i >= n {
        string.append(UnicodeScalar("["))
        item.text!.writeReconMarkupText(&string)
        string.append(UnicodeScalar("]"))
      } else if !inMarkup && item.isValue && !item.isRecord && (!first && i >= n || i < n && items[i].isAttr) {
        if !first && (item.isText && item.text!.isIdent || item.isNumber) {
          string.append(UnicodeScalar(" "))
        }
        item.writeRecon(&string)
      } else {
        string.append(UnicodeScalar("{"))
        item.writeRecon(&string)
        inBraces = true
        first = false
      }
    }
    if inBraces {
      string.append(UnicodeScalar("}"))
    } else if inBrackets {
      string.append(UnicodeScalar("]"))
    }
  }

  public func writeRecon(inout string: String) {
    if !isEmpty {
      writeReconRecord(&string, inBlock: false, inMarkup: false)
    } else {
      string.append(UnicodeScalar("{"))
      string.append(UnicodeScalar("}"))
    }
  }

  public func writeReconBlock(inout string: String) {
    if !isEmpty {
      writeReconRecord(&string, inBlock: isBlockSafe, inMarkup: false)
    } else {
      string.append(UnicodeScalar("{"))
      string.append(UnicodeScalar("}"))
    }
  }

  public var recon: String {
    var string = ""
    writeRecon(&string)
    return string
  }

  public var reconBlock: String {
    var string = ""
    writeReconBlock(&string)
    return string
  }

  mutating func reindex() {
    if items.count > Record.indexThreshold || self.fields != nil {
      var fields = [Value: Value]()
      for item in items {
        if case .Field(let field) = item {
          fields.updateValue(field.value, forKey: field.key)
        }
      }
      self.fields = fields
    }
  }

  public var json: [String: AnyObject] {
    var result = [String: AnyObject]()
    for item in items {
      guard let key = item.key?.text else {
        preconditionFailure("Cannot convert ReconValue to JSON key: \(item)")
      }
      result[key] = item.value.json
    }
    return result
  }

  public var description: String {
    return recon
  }

  public var hashValue: Int {
    var h = Int(bitPattern: 0x2494fd1f)
    for item in items {
      h = MurmurHash3.mix(h, item.hashValue)
    }
    h = MurmurHash3.mash(h)
    return h
  }
}

public func == (lhs: Record, rhs: Record) -> Bool {
  return lhs.items == rhs.items
}

public func < (lhs: Record, rhs: Record) -> Bool {
  let p = lhs.count
  let q = rhs.count
  let n = min(p, q)
  var i = 0
  while i < n {
    if lhs[i] < rhs[i] {
      return true
    }
    i += 1
  }
  return p < q
}
