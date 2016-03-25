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

    func onEventMessages(messages: [EventMessage]) {
        delegate?.downlink(self, events: messages)
    }

    func onCommandMessage(message: CommandMessage) {
        onCommandMessages([message])
    }

    func onCommandMessages(messages: [CommandMessage]) {
        delegate?.downlink(self, commands: messages)
    }

    func onLinkRequest(request: LinkRequest) {
        delegate?.downlink(self, willLink: request)
    }

    func onLinkedResponse(response: LinkedResponse) {
        delegate?.downlink(self, didLink: response)
    }

    func onSyncRequest(request: SyncRequest) {
        delegate?.downlink(self, willSync: request)
    }

    func onSyncedResponse(response: SyncedResponse) {
        delegate?.downlink(self, didSync: response)
    }

    func onUnlinkRequest(request: UnlinkRequest) {
        delegate?.downlink(self, willUnlink: request)
    }

    func onUnlinkedResponse(response: UnlinkedResponse) {
        delegate?.downlink(self, didUnlink: response)
    }

    func onConnect() {
        delegate?.downlinkDidConnect(self)
    }

    func onDisconnect() {
        delegate?.downlinkDidDisconnect(self)
        if !keepAlive {
            close()
        }
    }

    func onError(error: NSError) {}

    func onClose() {
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
