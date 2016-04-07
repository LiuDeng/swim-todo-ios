//
//  SwimListManager.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 2/15/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import Foundation
import Recon

private let log = SwimLogging.log


public protocol SwimListManagerProtocol: class {
    var objects: [SwimModelProtocolBase] { get }
    var laneScope: LaneScope? { get set }

    /**
     - parameter delegate: Will be weakly referenced by this SwimListManager.
     */
    func addDelegate(delegate: SwimListManagerDelegate)

    func removeDelegate(delegate: SwimListManagerDelegate)

    func startSynching()
    func stopSynching()

    /**
     This will fail, and return nil, if the server connection is not open.
     */
    func insertNewObjectAtIndex(index: Int) -> Any?

    func moveObjectAtIndex(fromIndex: Int, toIndex: Int)
    func removeObjectAtIndex(index: Int)
    func setHighlightAtIndex(index: Int, isHighlighted: Bool)
    func updateObjectAtIndex(index: Int)
}


public protocol SwimListManagerDelegate: class {
    /**
     Will be called whenever commands are received that will change SwimListManagerProtocol.objects,
     and before those commands are processed.

    In other words, this indicates the start of a batch of calls to swimDid{Insert,Move,Remove,Replace}.
     */
    func swimWillChangeObjects()

    /**
     Will be called after a batch of changes to SwimListManagerProtocol.objects has been processed.

     In other words, this indicates the end of a batch of calls to swimDid{Insert,Move,Remove,Replace}.
     */
    func swimDidChangeObjects()

    func swimDidInsert(object: SwimModelProtocolBase, atIndex: Int)
    func swimDidMove(fromIndex: Int, toIndex: Int)
    func swimDidRemove(index: Int, object: SwimModelProtocolBase)
    func swimDidUpdate(index: Int, object: SwimModelProtocolBase)

    func swimDidStartSynching()
    func swimDidLink()
    func swimDidStopSynching()
}

public extension SwimListManagerDelegate {
    public func swimWillChangeObjects() {}
    public func swimDidChangeObjects() {}

    public func swimDidInsert(object: SwimModelProtocolBase, atIndex: Int) {}
    public func swimDidMove(fromIndex: Int, toIndex: Int) {}
    public func swimDidRemove(index: Int, object: SwimModelProtocolBase) {}
    public func swimDidUpdate(index: Int, object: SwimModelProtocolBase) {}

    public func swimDidStartSynching() {}
    public func swimDidLink() {}
    public func swimDidStopSynching() {}
}


public class SwimListManager<ObjectType: SwimModelProtocol>: SwimListManagerProtocol, ListDownlinkDelegate {
    private var delegates = WeakArray<AnyObject>()

    public var objects: [SwimModelProtocolBase] {
        return downLink?.objects ?? []
    }

    public var laneScope: LaneScope? = nil

    private var downLink: ListDownlink? = nil

    public init() {
    }

    public func addDelegate(delegate: SwimListManagerDelegate) {
        SwimAssertOnMainThread()

        delegates.append(delegate)
    }

    public func removeDelegate(delegate: SwimListManagerDelegate) {
        SwimAssertOnMainThread()

        delegates.remove(delegate)
    }

    public func startSynching() {
        guard let ls = laneScope else {
            return
        }

        var dl = ls.syncList() { ObjectType(swimValue: $0) }
        dl.keepAlive = true
        dl.delegate = self
        downLink = dl

        forEachDelegate {
            $0.swimDidStartSynching()
        }
    }

    public func stopSynching() {
        guard let dl = downLink else {
            return
        }
        dl.close()
        downLink = nil

        forEachDelegate {
            $0.swimDidStopSynching()
        }
    }

    public func insertNewObjectAtIndex(index: Int) -> Any? {
        SwimAssertOnMainThread()

        guard let dl = downLink else {
            log.warning("Ignoring request to unsynched list")
            return nil
        }

        let object = ObjectType()
        dl.insert(object, atIndex: index)

        return object
    }

    public func moveObjectAtIndex(fromIndex: Int, toIndex: Int) {
        SwimAssertOnMainThread()

        guard let dl = downLink else {
            log.warning("Ignoring request to unsynched list")
            return
        }

        dl.moveFromIndex(fromIndex, toIndex: toIndex)
    }

    public func removeObjectAtIndex(index: Int) {
        SwimAssertOnMainThread()

        guard let dl = downLink else {
            log.warning("Ignoring request to unsynched list")
            return
        }

        dl.removeAtIndex(index)
    }

    public func setHighlightAtIndex(index: Int, isHighlighted: Bool) {
        SwimAssertOnMainThread()

        guard let dl = downLink else {
            log.warning("Ignoring request to unsynched list")
            return
        }

        let object = objects[index] as! ObjectType
        let cmd = (isHighlighted ? "highlight" : "unhighlight")
        log.verbose("Did \(cmd) \(index): \(object)")

        object.isHighlighted = isHighlighted
        dl.updateObjectAtIndex(index)
    }

    public func updateObjectAtIndex(index: Int) {
        SwimAssertOnMainThread()

        guard let dl = downLink else {
            log.warning("Ignoring request to unsynched list")
            return
        }

        dl.updateObjectAtIndex(index)
    }

    public func downlink(_: ListDownlink, didInsert object: SwimModelProtocolBase, atIndex index: Int) {
        forEachDelegate {
            $0.swimDidInsert(object, atIndex: index)
        }
    }

    public func downlink(_: ListDownlink, didUpdate object: SwimModelProtocolBase, atIndex index: Int) {
        forEachDelegate {
            $0.swimDidUpdate(index, object: object)
        }
    }

    public func downlink(_: ListDownlink, didMove _: SwimModelProtocolBase, fromIndex: Int, toIndex: Int) {
        forEachDelegate {
            $0.swimDidMove(fromIndex, toIndex: toIndex)
        }
    }

    public func downlink(_: ListDownlink, didRemove object: SwimModelProtocolBase, atIndex index: Int) {
        forEachDelegate {
            $0.swimDidRemove(index, object: object)
        }
    }

    public func downlinkWillChangeObjects(_: ListDownlink) {
        forEachDelegate {
            $0.swimWillChangeObjects()
        }
    }

    public func downlinkDidChangeObjects(_: ListDownlink) {
        forEachDelegate {
            $0.swimDidChangeObjects()
        }
    }

    public func downlink(_: Downlink, didLink _: LinkedResponse) {
        forEachDelegate {
            $0.swimDidLink()
        }
    }

    public func downlink(_: Downlink, didUnlink _: UnlinkedResponse) {
        stopSynching()
    }


    private func forEachDelegate(f: (SwimListManagerDelegate -> ())) {
        SwimAssertOnMainThread()

        delegates.forEach {
            f($0 as! SwimListManagerDelegate)
        }
    }
}
