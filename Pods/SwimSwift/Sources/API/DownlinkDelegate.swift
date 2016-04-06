public protocol DownlinkDelegate {
    func downlink(downlink: Downlink, events: [EventMessage])

    func downlinkWillLink(downlink: Downlink)

    func downlink(downlink: Downlink, didLink response: LinkedResponse)

    func downlinkWillSync(downlink: Downlink)

    func downlink(downlink: Downlink, didSync response: SyncedResponse)

    func downlinkWillUnlink(downlink: Downlink)

    func downlink(downlink: Downlink, didUnlink response: UnlinkedResponse)

    func downlinkDidConnect(downlink: Downlink)

    func downlinkDidDisconnect(downlink: Downlink)

    func downlinkDidClose(downlink: Downlink)
}

public extension DownlinkDelegate {
    public func downlink(downlink: Downlink, events: [EventMessage]) {}

    public func downlinkWillLink(downlink: Downlink) {}

    public func downlink(downlink: Downlink, didLink response: LinkedResponse) {}

    public func downlinkWillSync(downlink: Downlink) {}

    public func downlink(downlink: Downlink, didSync response: SyncedResponse) {}

    public func downlinkWillUnlink(downlink: Downlink) {}

    public func downlink(downlink: Downlink, didUnlink response: UnlinkedResponse) {}

    public func downlinkDidConnect(downlink: Downlink) {}

    public func downlinkDidDisconnect(downlink: Downlink) {}

    public func downlinkDidClose(downlink: Downlink) {}
}
