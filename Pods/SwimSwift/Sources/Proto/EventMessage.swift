import Recon

public class EventMessage: RoutableEnvelope, Equatable, CustomStringConvertible {
  public internal(set) var node: SwimUri
  public let lane: SwimUri
  public let body: Value

  public init(node: Uri, lane: Uri, body: Value = Value.Absent) {
    self.node = node
    self.lane = lane
    self.body = body
  }

  public convenience init?(value: Value) {
    let heading = value.first
    if heading.isAttr && heading.key?.text == "event", let headers = heading.value.record {
      var node = nil as Uri?
      var lane = nil as Uri?
      var i = 0
      for header in headers {
        if let key = header.key?.text {
          switch key {
          case "node":
            node = header.value.uri
          case "lane":
            lane = header.value.uri
          default: break
          }
        } else if header.isValue {
          switch i {
          case 0:
            node = header.uri
          case 1:
            lane = header.uri
          default: break
          }
        }
        i += 1
      }
      let body = value.record?.count > 1 ? value.dropFirst() : Value.Absent
      if node != nil && lane != nil {
        self.init(node: node!, lane: lane!, body: body)
      } else {
        return nil
      }
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
    let heading = Record()
    heading.append(Slot("node", Value(node)))
    heading.append(Slot("lane", Value(lane)))
    let record = Record(Attr("event", Value(heading)))
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

public func == (lhs: EventMessage, rhs: EventMessage) -> Bool {
  return lhs.node == rhs.node && lhs.lane == rhs.lane && lhs.body == rhs.body
}
