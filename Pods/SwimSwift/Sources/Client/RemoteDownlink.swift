import Bolts
import Foundation


private let log = SwimLogging.log


class RemoteDownlink: Downlink, Hashable {
    unowned let channel: Channel

    let hostUri: SwimUri

    let nodeUri: SwimUri

    let laneUri: SwimUri

    let laneProperties: LaneProperties

    var keepAlive: Bool = false

    var delegate: DownlinkDelegate? = nil

    /**
     Commands that have been sent to self.channel and for which we have not
     yet received an ack.
     */
    private let inFlightCommands = TaskQueue()

    /**
     SyncRequests that have been sent to self.channel and for which we have
     not yet received a SyncedResponse
     */
    private let inFlightSyncRequests = TaskQueue()

    init(channel: Channel, host: SwimUri, node: SwimUri, lane: SwimUri, laneProperties: LaneProperties) {
        self.channel = channel
        self.hostUri = host
        self.nodeUri = node
        self.laneUri = lane
        self.laneProperties = laneProperties
    }

    var connected: Bool {
        return channel.isConnected
    }

    func onAcks(messages: [AckResponse]) {
        messages.forEach {
            inFlightCommands.ack($0.commands)
        }

        delegate?.downlink(self, acks: messages)
    }

    func onEventMessages(messages: [EventMessage]) {
        delegate?.downlink(self, events: messages)
    }

    func onLinkedResponse(response: LinkedResponse) {
        delegate?.downlink(self, didLink: response)
    }

    func onSyncedResponse(response: SyncedResponse) {
        inFlightSyncRequests.ack(1)
        delegate?.downlink(self, didSync: response)
    }

    func onUnlinkRequest() {
        delegate?.downlinkWillUnlink(self)
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

    func command(body body: SwimValue) -> BFTask {
        let task = BFTaskCompletionSource()
        channel.command(node: nodeUri, lane: laneUri, body: body)
        inFlightCommands.append(task)
        return task.task
    }

    func sendSyncRequest() -> BFTask {
        delegate?.downlinkWillSync(self)
        let task = BFTaskCompletionSource()
        channel.pushSyncRequest(node: nodeUri, lane: laneUri, prio: laneProperties.prio)
        inFlightSyncRequests.append(task)
        return task.task
    }

    func close() {
        failAllInFlight()
        channel.unregisterDownlink(self)
    }

    private func failAllInFlight() {
        let err = NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost, userInfo: nil)
        inFlightCommands.failAll(err)
        inFlightSyncRequests.failAll(err)
    }

    var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
}

func == (lhs: RemoteDownlink, rhs: RemoteDownlink) -> Bool {
    return lhs === rhs
}
