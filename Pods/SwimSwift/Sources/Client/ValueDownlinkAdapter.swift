//
//  ValueDownlinkAdapter.swift
//  Swim
//
//  Created by Ewan Mellor on 5/14/16.
//
//

import Bolts
import Foundation
import Recon


private let log = SwimLogging.log


class ValueDownlinkAdapter: SynchedDownlinkAdapter, ValueDownlink {
    var object: SwimModelProtocolBase?

    private let objectMaker: (SwimValue -> SwimModelProtocolBase?)


    init(downlink: Downlink, objectMaker: (SwimValue -> SwimModelProtocolBase?)) {
        self.objectMaker = objectMaker
        super.init(downlink: downlink)
        uplink = self
    }


    override func swimDownlink(downlink: Downlink, events: [EventMessage]) {
        super.swimDownlink(downlink, events: events)

        var obj = object
        for event in events {
            if obj == nil {
                obj = objectMaker(event.body)
                if obj!.swimId == "" {
                    obj?.swimId = String(nodeUri).componentsSeparatedByString("/").last!
                }
                object = obj
            }
            else {
                obj!.swim_updateWithSwimValue(event.body)
            }
        }

        forEachValueDelegate {
            $0.swimValueDownlink($1, didUpdate: obj!)
        }
    }

    private func forEachValueDelegate(f: (ValueDownlinkDelegate, ValueDownlink) -> ()) {
        forEachDelegate { [weak self] (delegate, _) in
            guard let delegate = delegate as? ValueDownlinkDelegate, downlink = self as? ValueDownlink else {
                return
            }
            f(delegate, downlink)
        }
    }
}
