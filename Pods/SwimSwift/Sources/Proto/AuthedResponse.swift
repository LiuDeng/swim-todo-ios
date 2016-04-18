import Recon

public class AuthedResponse: Envelope, Equatable, CustomStringConvertible {
  public let body: Value

  public init(body: Value = Value.Absent) {
    self.body = body
  }

  public convenience init?(value: Value) {
    let heading = value.first
    if heading.isAttr && heading.key?.text == "authed" {
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
    let record = Record(Attr("authed"))
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

public func == (lhs: AuthedResponse, rhs: AuthedResponse) -> Bool {
  return lhs.body == rhs.body
}
