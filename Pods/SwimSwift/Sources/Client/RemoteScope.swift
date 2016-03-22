class RemoteScope {
  var downlinks: Set<RemoteDownlink> = Set<RemoteDownlink>()

  func registerDownlink(downlink: RemoteDownlink) {
    downlinks.insert(downlink)
  }

  func unregisterDownlink(downlink: RemoteDownlink) {
    downlinks.remove(downlink)
  }

  func close() {
    let downlinks = self.downlinks
    self.downlinks.removeAll()
    for downlink in downlinks {
      downlink.close()
    }
  }
}
