import Bolts
import Foundation


private let log = SwimLogging.log


class RemoteDownlink: DownlinkBase, Downlink {
    unowned let channel: Channel

    let hostUri: SwimUri

    let nodeUri: SwimUri

    let laneUri: SwimUri

    let laneProperties: LaneProperties

    var keepAlive: Bool = false

    /**
     Commands that have been sent to self.channel and for which we have not
     yet received an ack.
     */
    private let inFlightCommands = TaskQueue()

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

        forEachDelegate {
            $0.swimDownlink($1, acks: messages)
        }
    }

    func onEventMessages(messages: [EventMessage]) {
        forEachDelegate {
            $0.swimDownlink($1, events: messages)
        }
    }

    func onLinkedResponse(response: LinkedResponse) {
        forEachDelegate {
            $0.swimDownlink($1, didLink: response)
        }
    }

    func onSyncedResponse(response: SyncedResponse) {
        forEachDelegate {
            $0.swimDownlink($1, didSync: response)
        }
    }

    func onUnlinkRequest() {
        forEachDelegate {
            $0.swimDownlinkWillUnlink($1)
        }
    }

    func onUnlinkedResponse(response: UnlinkedResponse) {
        let tag = response.body.tag
        if tag == "nodeNotFound" {
            sendDidReceiveError(SwimError.NodeNotFound)
        }
        else if tag == "laneNotFound" {
            sendDidReceiveError(SwimError.LaneNotFound)
        }

        forEachDelegate {
            $0.swimDownlink($1, didUnlink: response)
        }
    }

    func onConnect() {
        forEachDelegate {
            $0.swimDownlinkDidConnect($1)
        }
    }

    func onDisconnect() {
        forEachDelegate {
            $0.swimDownlinkDidDisconnect($1)
        }
        if !keepAlive {
            close()
        }
    }

    func onError(error: NSError) {
        failAllInFlight(error)
    }

    func onClose() {
        forEachDelegate {
            $0.swimDownlinkDidClose($1)
        }
    }

    func didLoseSync() {
        forEachDelegate {
            $0.swimDownlinkDidLoseSync($1)
        }
    }

    func command(body body: SwimValue) -> BFTask {
        if laneProperties.isClientReadOnly {
            return BFTask(swimError: .DownlinkIsClientReadOnly)
        }

        let task = BFTaskCompletionSource()
        channel.command(node: nodeUri, lane: laneUri, body: body)
        inFlightCommands.append(task)
        return task.task
    }

    func sendSyncRequest() {
        forEachDelegate {
            $0.swimDownlinkWillSync($1)
        }
        channel.pushSyncRequest(node: nodeUri, lane: laneUri, prio: laneProperties.prio)
    }

    func close() {
        let err = NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost, userInfo: nil)
        failAllInFlight(err)
        channel.unregisterDownlink(self)
    }

    private func failAllInFlight(err: NSError) {
        inFlightCommands.failAll(err)
    }
}
