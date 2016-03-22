public protocol DownlinkDelegate {
    func downlink(downlink: Downlink, event message: EventMessage)

    func downlink(downlink: Downlink, command message: CommandMessage)

    func downlink(downlink: Downlink, willLink request: LinkRequest)

    func downlink(downlink: Downlink, didLink response: LinkedResponse)

    func downlink(downlink: Downlink, willSync request: SyncRequest)

    func downlink(downlink: Downlink, didSync response: SyncedResponse)

    func downlink(downlink: Downlink, willUnlink request: UnlinkRequest)

    func downlink(downlink: Downlink, didUnlink response: UnlinkedResponse)

    func downlinkDidConnect(downlink: Downlink)

    func downlinkDidDisconnect(downlink: Downlink)

    func downlinkDidClose(downlink: Downlink)
}

public extension DownlinkDelegate {
    public func downlink(downlink: Downlink, event message: EventMessage) {}

    public func downlink(downlink: Downlink, command message: CommandMessage) {}

    public func downlink(downlink: Downlink, willLink request: LinkRequest) {}

    public func downlink(downlink: Downlink, didLink response: LinkedResponse) {}

    public func downlink(downlink: Downlink, willSync request: SyncRequest) {}

    public func downlink(downlink: Downlink, didSync response: SyncedResponse) {}

    public func downlink(downlink: Downlink, willUnlink request: UnlinkRequest) {}

    public func downlink(downlink: Downlink, didUnlink response: UnlinkedResponse) {}

    public func downlinkDidConnect(downlink: Downlink) {}

    public func downlinkDidDisconnect(downlink: Downlink) {}

    public func downlinkDidClose(downlink: Downlink) {}
}
