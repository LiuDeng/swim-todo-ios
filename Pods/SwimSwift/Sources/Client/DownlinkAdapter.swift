//
//  DownlinkAdapter.swift
//  Swim
//
//  Created by Ewan Mellor on 4/13/16.
//
//

import Bolts
import Foundation


/**
 A base class that acts as an adapter to a Downlink, to create a different
 Downlink.  This can be used to add additional behavior in the Downlink
 path.

 This class implements the entire Downlink and DownlinkDelegate protocols,
 forwarding the calls between self.downlink and the subclass (self.uplink).
 Any of these forwarding calls can of course be intercepted by the subclass
 to modify the behavior on the way through.
 */
class DownlinkAdapter: DownlinkDelegate {
    /// Must be set to self by the subclass's init method.
    var uplink: Downlink!

    var downlink: Downlink

    var delegate: DownlinkDelegate?

    var hostUri: SwimUri {
        return downlink.hostUri
    }
    var nodeUri: SwimUri {
        return downlink.nodeUri
    }
    var laneUri: SwimUri {
        return downlink.laneUri
    }
    var laneProperties: LaneProperties {
        return downlink.laneProperties
    }
    var connected: Bool {
        return downlink.connected
    }
    var keepAlive: Bool {
        get {
            return downlink.keepAlive
        }
        set {
            downlink.keepAlive = newValue
        }
    }

    init(downlink: Downlink) {
        self.downlink = downlink
        downlink.delegate = self
    }


    func command(body body: SwimValue) -> BFTask {
        return downlink.command(body: body)
    }


    func sendSyncRequest() -> BFTask {
        return downlink.sendSyncRequest()
    }


    func close() {
        downlink.close()
    }


    // MARK: - DownlinkDelegate

    func downlink(downlink: Downlink, acks: [AckResponse]) {
        delegate?.downlink(uplink, acks: acks)
    }

    func downlink(downlink: Downlink, events: [EventMessage]) {
        delegate?.downlink(uplink, events: events)
    }

    func downlinkWillLink(downlink: Downlink) {
        delegate?.downlinkWillLink(uplink)
    }

    func downlink(downlink: Downlink, didLink response: LinkedResponse) {
        delegate?.downlink(downlink, didLink: response)
    }

    func downlinkWillSync(downlink: Downlink) {
        delegate?.downlinkWillSync(uplink)
    }

    func downlink(downlink: Downlink, didSync response: SyncedResponse) {
        delegate?.downlink(downlink, didSync: response)
    }

    func downlinkWillUnlink(downlink: Downlink) {
        delegate?.downlinkWillUnlink(uplink)
    }

    func downlink(downlink: Downlink, didUnlink response: UnlinkedResponse) {
        delegate?.downlink(uplink, didUnlink: response)
    }

    func downlinkDidConnect(downlink: Downlink) {
        delegate?.downlinkDidConnect(uplink)
    }

    func downlinkDidDisconnect(downlink: Downlink) {
        delegate?.downlinkDidDisconnect(uplink)
    }

    func downlinkDidClose(downlink: Downlink) {
        delegate?.downlinkDidClose(uplink)
    }
}


/**
 A small extension to DownlinkAdapter that simply calls sendSyncRequest
 when downlinkDidConnect is received.  In other words, it starts to
 synchronize as soon as the lane is connected.
 */
class SynchedDownlinkAdapter: DownlinkAdapter {
    override func downlinkDidConnect(downlink: Downlink) {
        downlink.sendSyncRequest()
        super.downlinkDidConnect(uplink)
    }
}
