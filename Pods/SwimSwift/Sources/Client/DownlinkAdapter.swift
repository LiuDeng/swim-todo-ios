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
class DownlinkAdapter: DownlinkBase, DownlinkDelegate {
    /// Must be set to self by the subclass's init method.
    var uplink: Downlink!

    var downlink: Downlink

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
        super.init()
        downlink.addDelegate(self)
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

    func swimDownlink(downlink: Downlink, acks: [AckResponse]) {
        forEachDelegate {
            $0.swimDownlink($1, acks: acks)
        }
    }

    func swimDownlink(downlink: Downlink, events: [EventMessage]) {
        forEachDelegate {
            $0.swimDownlink($1, events: events)
        }
    }

    func swimDownlinkWillLink(downlink: Downlink) {
        forEachDelegate {
            $0.swimDownlinkWillLink($1)
        }
    }

    func swimDownlink(downlink: Downlink, didLink response: LinkedResponse) {
        forEachDelegate {
            $0.swimDownlink($1, didLink: response)
        }
    }

    func swimDownlinkWillSync(downlink: Downlink) {
        forEachDelegate {
            $0.swimDownlinkWillSync($1)
        }
    }

    func swimDownlink(downlink: Downlink, didSync response: SyncedResponse) {
        forEachDelegate {
            $0.swimDownlink($1, didSync: response)
        }
    }

    func swimDownlinkWillUnlink(downlink: Downlink) {
        forEachDelegate {
            $0.swimDownlinkWillUnlink($1)
        }
    }

    func swimDownlink(downlink: Downlink, didUnlink response: UnlinkedResponse) {
        forEachDelegate {
            $0.swimDownlink($1, didUnlink: response)
        }
    }

    func swimDownlinkDidConnect(downlink: Downlink) {
        forEachDelegate {
            $0.swimDownlinkDidConnect($1)
        }
    }

    func swimDownlinkDidDisconnect(downlink: Downlink) {
        forEachDelegate {
            $0.swimDownlinkDidDisconnect($1)
        }
    }

    func swimDownlinkDidClose(downlink: Downlink) {
        forEachDelegate {
            $0.swimDownlinkDidClose($1)
        }
    }
}


/**
 A small extension to DownlinkAdapter that simply calls sendSyncRequest
 when downlinkDidConnect is received.  In other words, it starts to
 synchronize as soon as the lane is connected.
 */
class SynchedDownlinkAdapter: DownlinkAdapter {
    override func swimDownlinkDidConnect(downlink: Downlink) {
        downlink.sendSyncRequest()
        super.swimDownlinkDidConnect(uplink)
    }
}
