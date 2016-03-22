protocol ReconBuilder {
  mutating func append(item: Item)

  mutating func appendField(field: Field)

  mutating func appendValue(value: Value)

  mutating func appendAttr(key: String)

  mutating func appendAttr(key: String, _ value: Value)

  mutating func appendSlot(key: Value)

  mutating func appendSlot(key: Value, _ value: Value)

  mutating func appendRecord(value: Record)

  mutating func appendText(value: String)

  mutating func appendData(value: Data)

  mutating func appendNumber(value: Double)

  mutating func appendAny(value: Any)

  var state: Value { get }
}

extension ReconBuilder {
  mutating func appendField(field: Field) {
    append(Item.Field(field))
  }

  mutating func appendValue(value: Value) {
    append(Item.Value(value))
  }

  mutating func appendAttr(key: String) {
    append(Item.Field(Field.Attr(key, Value.Extant)))
  }

  mutating func appendAttr(key: String, _ value: Value) {
    append(Item.Field(Field.Attr(key, value)))
  }

  mutating func appendSlot(key: Value) {
    append(Item.Field(Field.Slot(key, Value.Extant)))
  }

  mutating func appendSlot(key: Value, _ value: Value) {
    append(Item.Field(Field.Slot(key, value)))
  }

  mutating func appendRecord(value: Record) {
    appendValue(Value.Record(value))
  }

  mutating func appendText(value: String) {
    appendValue(Value.Text(value))
  }

  mutating func appendData(value: Data) {
    appendValue(Value.Data(value))
  }

  mutating func appendNumber(value: Double) {
    appendValue(Value.Number(value))
  }

  mutating func appendAny(value: Any) {
    switch value {
    case let value as Record:
      appendRecord(value)
    case let value as String:
      appendText(value)
    case let value as Data:
      appendData(value)
    case let value as Double:
      appendNumber(value)
    case let value as Int:
      appendNumber(Double(value))
    default:
      fatalError("unknown value: \(value)")
    }
  }
}

class RecordBuilder: ReconBuilder {
  var record: Record

  init(_ record: Record) {
    self.record = record
  }

  convenience init() {
    self.init(Record())
  }

  func append(item: Item) {
    record.append(item)
  }

  var state: Value {
    return Value.Record(record)
  }
}

class ValueBuilder: ReconBuilder {
  var record: Record?
  var value: Value?

  init() {
    self.record = nil
    self.value = nil
  }

  func append(item: Item) {
    if self.record != nil {
      self.record!.append(item)
    } else if case .Value(let value) = item where self.value == nil {
      self.value = value
    } else {
      var record = Record()
      if let value = self.value {
        record.append(Item.Value(value))
        self.value = nil
      }
      record.append(item)
      self.record = record
    }
  }

  var state: Value {
    if let value = self.value {
      return value
    } else if let record = self.record {
      return Value.Record(record)
    } else {
      return Value.Absent
    }
  }
}
