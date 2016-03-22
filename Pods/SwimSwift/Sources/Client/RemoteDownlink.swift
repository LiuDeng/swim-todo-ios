import Foundation

class RemoteDownlink: Downlink, Hashable {
    unowned let channel: Channel

    weak var scope: RemoteScope?

    let hostUri: SwimUri

    let nodeUri: SwimUri

    let laneUri: SwimUri

    let prio: Double

    var keepAlive: Bool = false

    var delegate: DownlinkDelegate? = nil

    var event: (EventMessage -> Void)? = nil

    var command: (CommandMessage -> Void)? = nil

    var willLink: (LinkRequest -> Void)? = nil

    var didLink: (LinkedResponse -> Void)? = nil

    var willSync: (SyncRequest -> Void)? = nil

    var didSync: (SyncedResponse -> Void)? = nil

    var willUnlink: (UnlinkRequest -> Void)? = nil

    var didUnlink: (UnlinkedResponse -> Void)? = nil

    var didConnect: (() -> Void)? = nil

    var didDisconnect: (() -> Void)? = nil

    var didClose: (() -> Void)? = nil

    init(channel: Channel, scope: RemoteScope?, host: SwimUri, node: SwimUri, lane: SwimUri, prio: Double) {
        self.channel = channel
        self.scope = scope
        self.hostUri = host
        self.nodeUri = node
        self.laneUri = lane
        self.prio = prio
    }

    var connected: Bool {
        return channel.isConnected
    }

    func onEventMessage(message: EventMessage) {
        event?(message)
        delegate?.downlink(self, event: message)
    }

    func onCommandMessage(message: CommandMessage) {
        command?(message)
        delegate?.downlink(self, command: message)
    }

    func onLinkRequest(request: LinkRequest) {
        willLink?(request)
        delegate?.downlink(self, willLink: request)
    }

    func onLinkedResponse(response: LinkedResponse) {
        didLink?(response)
        delegate?.downlink(self, didLink: response)
    }

    func onSyncRequest(request: SyncRequest) {
        willSync?(request)
        delegate?.downlink(self, willSync: request)
    }

    func onSyncedResponse(response: SyncedResponse) {
        didSync?(response)
        delegate?.downlink(self, didSync: response)
    }

    func onUnlinkRequest(request: UnlinkRequest) {
        willUnlink?(request)
        delegate?.downlink(self, willUnlink: request)
    }

    func onUnlinkedResponse(response: UnlinkedResponse) {
        didUnlink?(response)
        delegate?.downlink(self, didUnlink: response)
    }

    func onConnect() {
        didConnect?()
        delegate?.downlinkDidConnect(self)
    }

    func onDisconnect() {
        didDisconnect?()
        delegate?.downlinkDidDisconnect(self)
        if !keepAlive {
            close()
        }
    }

    func onError(error: NSError) {}

    func onClose() {
        didClose?()
        delegate?.downlinkDidClose(self)
    }

    func command(body body: SwimValue) {
        channel.command(node: nodeUri, lane: laneUri, body: body)
    }

    func close() {
        scope?.unregisterDownlink(self)
        channel.unregisterDownlink(self)
    }

    var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
}

func == (lhs: RemoteDownlink, rhs: RemoteDownlink) -> Bool {
    return lhs === rhs
}
