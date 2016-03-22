import Recon

public struct Proto {
  private init() {}

  public static func decode(value value: Value) -> Envelope? {
    let heading = value.first
    if heading.isAttr, let key = heading.key?.text {
      switch key {
      case "event":
        return EventMessage(value: value)
      case "command":
        return CommandMessage(value: value)
      case "link":
        return LinkRequest(value: value)
      case "linked":
        return LinkedResponse(value: value)
      case "sync":
        return SyncRequest(value: value)
      case "synced":
        return SyncedResponse(value: value)
      case "unlink":
        return UnlinkRequest(value: value)
      case "unlinked":
        return UnlinkedResponse(value: value)
      case "auth":
        return AuthRequest(value: value)
      case "authed":
        return AuthedResponse(value: value)
      case "deauth":
        return DeauthRequest(value: value)
      case "deauthed":
        return DeauthedResponse(value: value)
      default:
        return nil
      }
    } else {
      return nil
    }
  }

  public static func parse(recon recon: String) -> Envelope? {
    guard let value = Recon.recon(recon) else {
      return nil
    }
    return decode(value: value)
  }
}
