import Recon

public struct SyncedResponse: Envelope, Equatable {
  public let node: Uri
  public let lane: Uri
  public let body: Value

  public init(node: Uri, lane: Uri, body: Value = Value.Absent) {
    self.node = node
    self.lane = lane
    self.body = body
  }

  public init?(value: Value) {
    let heading = value.first
    if heading.isAttr && heading.key?.text == "synced", let headers = heading.value.record {
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

  public init?(recon string: String) {
    guard let value = Recon.recon(string) else {
      return nil
    }
    self.init(value: value)
  }

  public func withNode(node: Uri, lane: Uri) -> SyncedResponse {
    return SyncedResponse(node: node, lane: lane, body: body)
  }

  public func withNode(node: Uri) -> SyncedResponse {
    return SyncedResponse(node: node, lane: lane, body: body)
  }

  public var reconValue: Value {
    var heading = Record()
    heading.append(Slot("node", Value(node)))
    heading.append(Slot("lane", Value(lane)))
    var record = Record(Attr("synced", Value(heading)))
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

public func == (lhs: SyncedResponse, rhs: SyncedResponse) -> Bool {
  return lhs.node == rhs.node && lhs.lane == rhs.lane && lhs.body == rhs.body
}
