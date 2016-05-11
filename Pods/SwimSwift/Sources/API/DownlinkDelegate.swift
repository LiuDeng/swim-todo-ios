public protocol DownlinkDelegate: class {
    func swimDownlink(downlink: Downlink, acks: [AckResponse])

    func swimDownlink(downlink: Downlink, events: [EventMessage])

    func swimDownlinkWillLink(downlink: Downlink)

    func swimDownlink(downlink: Downlink, didLink response: LinkedResponse)

    func swimDownlinkWillSync(downlink: Downlink)

    func swimDownlink(downlink: Downlink, didSync response: SyncedResponse)

    func swimDownlinkWillUnlink(downlink: Downlink)

    func swimDownlink(downlink: Downlink, didUnlink response: UnlinkedResponse)

    func swimDownlinkDidConnect(downlink: Downlink)

    func swimDownlinkDidDisconnect(downlink: Downlink)

    func swimDownlinkDidClose(downlink: Downlink)

    func swimDownlink(downlink: Downlink, didCompleteServerWritesOfObject object: SwimModelProtocolBase)

    func swimDownlink(downlink: Downlink, didReceiveError error: ErrorType)

    func swimDownlinkDidLoseSync(downlink: Downlink)
}

public extension DownlinkDelegate {
    public func swimDownlink(downlink: Downlink, acks: [AckResponse]) {}

    public func swimDownlink(downlink: Downlink, events: [EventMessage]) {}

    public func swimDownlinkWillLink(downlink: Downlink) {}

    public func swimDownlink(downlink: Downlink, didLink response: LinkedResponse) {}

    public func swimDownlinkWillSync(downlink: Downlink) {}

    public func swimDownlink(downlink: Downlink, didSync response: SyncedResponse) {}

    public func swimDownlinkWillUnlink(downlink: Downlink) {}

    public func swimDownlink(downlink: Downlink, didUnlink response: UnlinkedResponse) {}

    public func swimDownlinkDidConnect(downlink: Downlink) {}

    public func swimDownlinkDidDisconnect(downlink: Downlink) {}

    public func swimDownlinkDidClose(downlink: Downlink) {}

    public func swimDownlink(downlink: Downlink, didCompleteServerWritesOfObject object: SwimModelProtocolBase) {}

    public func swimDownlink(downlink: Downlink, didReceiveError error: ErrorType) {}

    public func swimDownlinkDidLoseSync(downlink: Downlink) {}
}
