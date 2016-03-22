import Recon

public struct LinkedResponse: Envelope, Equatable {
  public let node: Uri
  public let lane: Uri
  public let prio: Double
  public let body: Value

  public init(node: Uri, lane: Uri, prio: Double = 0.0, body: Value = Value.Absent) {
    self.node = node
    self.lane = lane
    self.prio = prio
    self.body = body
  }

  public init?(value: Value) {
    let heading = value.first
    if heading.isAttr && heading.key?.text == "linked", let headers = heading.value.record {
      var node = nil as Uri?
      var lane = nil as Uri?
      var prio = 0.0
      var i = 0
      for header in headers {
        if let key = header.key?.text {
          switch key {
          case "node":
            node = header.value.uri
          case "lane":
            lane = header.value.uri
          case "prio":
            prio = header.value.number ?? 0.0
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
        self.init(node: node!, lane: lane!, prio: prio, body: body)
      } else {
        return nil
      }
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

  public func withNode(node: Uri, lane: Uri) -> LinkedResponse {
    return LinkedResponse(node: node, lane: lane, prio: prio, body: body)
  }

  public func withNode(node: Uri) -> LinkedResponse {
    return LinkedResponse(node: node, lane: lane, prio: prio, body: body)
  }

  public var reconValue: Value {
    var heading = Record()
    heading.append(Slot("node", Value(node)))
    heading.append(Slot("lane", Value(lane)))
    if prio != 0.0 {
      heading.append(Slot("prio", Value(prio)))
    }
    var record = Record(Attr("linked", Value(heading)))
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

public func == (lhs: LinkedResponse, rhs: LinkedResponse) -> Bool {
  return lhs.node == rhs.node && lhs.lane == rhs.lane &&
    lhs.prio == rhs.prio && lhs.body == rhs.body
}
