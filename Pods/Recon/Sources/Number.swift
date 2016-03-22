import Darwin

extension Double {
  public func writeRecon(inout string: String) {
    string.appendContentsOf(recon)
  }

  public var recon: String {
    if Double(Int64.min) <= self && self <= Double(Int64.max) && self == round(self) {
      return String(Int64(self))
    } else {
      return String(self)
    }
  }
}
