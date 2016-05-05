//
//  SwimMapManager.swift
//  Swim
//
//  Created by Ewan Mellor on 5/4/16.
//
//

import Foundation

private let log = SwimLogging.log


public class SwimMapManager: MapDownlinkDelegate {
    private var delegates = WeakArray<AnyObject>()

    public var objects: [SwimValue: SwimModelProtocolBase] {
        return downlink?.objects ?? [:]
    }

    public var objectMaker: (SwimValue -> SwimModelProtocolBase?)!
    public var newObjectMaker: (() -> SwimModelProtocolBase)!
    public var primaryKey: (SwimModelProtocolBase -> SwimValue)!

    public var laneScope: LaneScope? = nil

    public let laneProperties = LaneProperties()

    public var downlink: MapDownlink? = nil

    public init() {
    }

    public func addDelegate(delegate: DownlinkDelegate) {
        SwimAssertOnMainThread()

        delegates.append(delegate)
    }

    public func removeDelegate(delegate: DownlinkDelegate) {
        SwimAssertOnMainThread()

        delegates.remove(delegate)
    }

    public func startSynching() {
        precondition(laneScope != nil && objectMaker != nil && primaryKey != nil,
                     "Must configure lane before calling startSynching.")
        let ls = laneScope!
        let om = objectMaker!
        let pk = primaryKey!

        let dl = ls.syncMap(properties: laneProperties, objectMaker: om, primaryKey: pk)
        dl.keepAlive = true
        dl.addDelegate(self)
        for delegate in delegates {
            dl.addDelegate(delegate as! DownlinkDelegate)
        }
        downlink = dl
    }

    public func stopSynching() {
        guard let dl = downlink else {
            return
        }
        dl.close()
        // Note that we don't set downlink to nil here, because it has
        // to stay alive until swimDownlinkDidClose is called, because
        // that's how we provide a consistent view of the data store
        // until the close is entirely processed.
    }


    public func swimDownlinkDidClose(_: Downlink) {
        downlink = nil
    }


    public func downlink(_: Downlink, didUnlink response: UnlinkedResponse) {
        stopSynching()
    }
}
