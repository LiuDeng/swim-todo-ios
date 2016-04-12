import Recon

public class AuthRequest: Envelope, Equatable, CustomStringConvertible {
  public let body: Value

  public init(body: Value = Value.Absent) {
    self.body = body
  }

  public convenience init?(value: Value) {
    let heading = value.first
    if heading.isAttr && heading.key?.text == "auth" {
      let body = value.record?.count > 1 ? value.dropFirst() : Value.Absent
      self.init(body: body)
    } else {
      return nil
    }
  }

  public convenience init?(recon string: String) {
    guard let value = Recon.recon(string) else {
      return nil
    }
    self.init(value: value)
  }

  private var reconValue: Value {
    var record = Record(Attr("auth"))
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

  public var description: String {
    return recon
  }
}

public func == (lhs: AuthRequest, rhs: AuthRequest) -> Bool {
  return lhs.body == rhs.body
}
