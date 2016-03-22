import Recon

public struct DeauthedResponse: Envelope, Equatable {
  public var node: Uri {
    return Uri()
  }

  public var lane: Uri {
    return Uri()
  }

  public let body: Value

  public init(body: Value = Value.Absent) {
    self.body = body
  }

  public init?(value: Value) {
    let heading = value.first
    if heading.isAttr && heading.key?.text == "deauthed" {
      let body = value.record?.count > 1 ? value.dropFirst() : Value.Absent
      self.init(body: body)
    } else {
      return nil
    }
  }

  public init?(recon string: String) {
    guard let value = Recon.recon(string) else {
      return nil
    }
    self.init(value: value)
  }

  public var reconValue: Value {
    var record = Record(Attr("deauthed"))
    if let body = self.body.record {
      record.appendContentsOf(body)
    } else if body != Value.Absent {
      record.append(Item.Value(body))
    }
    return Value(record)
  }

  public var recon: String {
    return reconValue.recon
  }
}

public func == (lhs: DeauthedResponse, rhs: DeauthedResponse) -> Bool {
  return lhs.body == rhs.body
}
