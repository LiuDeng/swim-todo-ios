//
//  SwimListManager.swift
//  Swim
//
//  Created by Ewan Mellor on 2/15/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import Bolts
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
    func insertNewObjectAtIndex(index: Int) -> SwimModelProtocolBase?

    func moveObjectAtIndex(fromIndex: Int, toIndex: Int)

    /**
     This will fail, and return nil, if the server connection is not open.
     Otherwise, the removed object will be returned.
     */
    func removeObjectAtIndex(index: Int) -> SwimModelProtocolBase?

    /**
     This will fail, and return false, if the server connection is not open.
     */
    func removeAll() -> Bool

    func setHighlightAtIndex(index: Int, isHighlighted: Bool)
    func updateObjectAtIndex(index: Int)
}


public protocol SwimListManagerDelegate: class {
    /**
     Will be called whenever commands are received that will change SwimListManagerProtocol.objects,
     and before those commands are processed.

    In other words, this indicates the start of a batch of calls to swimDid{Insert,Move,Remove,Replace}.
     */
    func swimListWillChangeObjects(manager: SwimListManagerProtocol)

    /**
     Will be called after a batch of changes to SwimListManagerProtocol.objects has been processed.

     In other words, this indicates the end of a batch of calls to swimDid{Insert,Move,Remove,Replace}.
     */
    func swimListDidChangeObjects(manager: SwimListManagerProtocol)

    func swimList(manager: SwimListManagerProtocol, didInsertObjects objects: [SwimModelProtocolBase], atIndexes indexes: [Int])
    func swimList(manager: SwimListManagerProtocol, didMoveObjectFromIndex fromIndex: Int, toIndex: Int)
    func swimList(manager: SwimListManagerProtocol, didRemoveObject object: SwimModelProtocolBase, atIndex index: Int)
    func swimList(manager: SwimListManagerProtocol, didUpdateObject object: SwimModelProtocolBase, atIndex index: Int)

    func swimList(manager: SwimListManagerProtocol, didCompleteServerWritesOfObject object: SwimModelProtocolBase)

    func swimListDidStartSynching(manager: SwimListManagerProtocol)
    func swimListDidLink(manager: SwimListManagerProtocol)
    func swimListDidStopSynching(manager: SwimListManagerProtocol)

    func swimList(manager: SwimListManagerProtocol, didReceiveError error: ErrorType)
}

public extension SwimListManagerDelegate {
    func swimListWillChangeObjects(manager: SwimListManagerProtocol) {}
    func swimListDidChangeObjects(manager: SwimListManagerProtocol) {}

    func swimList(manager: SwimListManagerProtocol, didInsertObjects objects: [SwimModelProtocolBase], atIndexes indexes: [Int]) {}
    func swimList(manager: SwimListManagerProtocol, didMoveObjectFromIndex fromIndex: Int, toIndex: Int) {}
    func swimList(manager: SwimListManagerProtocol, didRemoveObject object: SwimModelProtocolBase, atIndex index: Int) {}
    func swimList(manager: SwimListManagerProtocol, didUpdateObject object: SwimModelProtocolBase, atIndex index: Int) {}

    func swimList(manager: SwimListManagerProtocol, didCompleteServerWritesOfObject object: SwimModelProtocolBase) {}

    func swimListDidStartSynching(manager: SwimListManagerProtocol) {}
    func swimListDidLink(manager: SwimListManagerProtocol) {}
    func swimListDidStopSynching(manager: SwimListManagerProtocol) {}

    public func swimList(manager: SwimListManagerProtocol, didReceiveError error: ErrorType) {}
}


public class SwimListManager<ObjectType: SwimModelProtocol>: SwimListManagerProtocol, ListDownlinkDelegate {
    private var delegates = WeakArray<AnyObject>()

    public var objects: [SwimModelProtocolBase] {
        return downLink?.objects ?? []
    }

    public var laneScope: LaneScope? = nil

    public let laneProperties = LaneProperties()

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

        let dl = ls.syncList(properties: laneProperties) { ObjectType(swimValue: $0) }
        dl.keepAlive = true
        dl.delegate = self
        downLink = dl

        forEachDelegate {
            $0.swimListDidStartSynching(self)
        }
    }

    public func stopSynching() {
        guard let dl = downLink else {
            return
        }
        dl.close()
        downLink = nil

        forEachDelegate {
            $0.swimListDidStopSynching(self)
        }
    }

    public func insertNewObjectAtIndex(index: Int) -> SwimModelProtocolBase? {
        SwimAssertOnMainThread()

        guard let dl = downLink else {
            log.warning("Ignoring request to unsynched list")
            return nil
        }

        let object = ObjectType()
        object.serverWritesInProgress += 1
        dl.insert(object, atIndex: index).continueWithBlock { [weak self] task in
            return didCompleteServerWrite(object, manager: self, task: task)
        }.continueWithBlock(handleFailures)

        return object
    }

    public func moveObjectAtIndex(fromIndex: Int, toIndex: Int) {
        SwimAssertOnMainThread()

        guard let dl = downLink else {
            log.warning("Ignoring request to unsynched list")
            return
        }

        dl.moveFromIndex(fromIndex, toIndex: toIndex).continueWithBlock(handleFailures)
    }

    public func removeObjectAtIndex(index: Int) -> SwimModelProtocolBase? {
        SwimAssertOnMainThread()

        guard let dl = downLink else {
            log.warning("Ignoring request to unsynched list")
            return nil
        }

        let (obj, task) = dl.removeAtIndex(index)
        task.continueWithBlock(handleFailures)
        return obj
    }

    public func removeAll() -> Bool {
        SwimAssertOnMainThread()

        guard let dl = downLink else {
            log.warning("Ignoring request to unsynched list")
            return false
        }

        let task = dl.removeAll()
        task.continueWithBlock(handleFailures)
        return true
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
        // Note that failures only get logged, they don't go back to the
        // delegate, to keep this call lightweight.
        dl.updateObjectAtIndex(index).continueWithBlock(logFailures)
    }

    public func updateObjectAtIndex(index: Int) {
        SwimAssertOnMainThread()

        guard let dl = downLink else {
            log.warning("Ignoring request to unsynched list")
            return
        }

        let object = objects[index] as! ObjectType
        object.serverWritesInProgress += 1
        dl.updateObjectAtIndex(index).continueWithBlock { [weak self] task in
            return didCompleteServerWrite(object, manager: self, task: task)
        }.continueWithBlock(handleFailures)
    }

    public func downlink(downlink: ListDownlink, didInsert objects: [SwimModelProtocolBase], atIndexes indexes: [Int]) {
        forEachDelegate {
            $0.swimList(self, didInsertObjects: objects, atIndexes: indexes)
        }
    }

    public func downlink(_: ListDownlink, didUpdate object: SwimModelProtocolBase, atIndex index: Int) {
        forEachDelegate {
            $0.swimList(self, didUpdateObject: object, atIndex: index)
        }
    }

    public func downlink(_: ListDownlink, didMove _: SwimModelProtocolBase, fromIndex: Int, toIndex: Int) {
        forEachDelegate {
            $0.swimList(self, didMoveObjectFromIndex: fromIndex, toIndex: toIndex)
        }
    }

    public func downlink(_: ListDownlink, didRemove object: SwimModelProtocolBase, atIndex index: Int) {
        forEachDelegate {
            $0.swimList(self, didRemoveObject: object, atIndex: index)
        }
    }

    public func downlinkWillChangeObjects(_: ListDownlink) {
        forEachDelegate {
            $0.swimListWillChangeObjects(self)
        }
    }

    public func downlinkDidChangeObjects(_: ListDownlink) {
        forEachDelegate {
            $0.swimListDidChangeObjects(self)
        }
    }

    public func downlink(_: Downlink, didLink _: LinkedResponse) {
        forEachDelegate {
            $0.swimListDidLink(self)
        }
    }

    public func downlink(_: Downlink, didUnlink response: UnlinkedResponse) {
        let tag = response.body.tag
        if tag == "nodeNotFound" {
            sendDidReceiveError(SwimError.NodeNotFound)
        }
        else if tag == "laneNotFound" {
            sendDidReceiveError(SwimError.LaneNotFound)
        }

        stopSynching()
    }


    private func sendDidReceiveError(err: ErrorType) {
        dispatch_async(dispatch_get_main_queue()) { [weak self] in
            self?.sendDidReceiveError_(err)
        }
    }

    private func sendDidReceiveError_(err: ErrorType) {
        forEachDelegate {
            $0.swimList(self, didReceiveError: err)
        }
    }


    private func sendDidCompleteServerWrites(object: ObjectType) {
        forEachDelegate {
            $0.swimList(self, didCompleteServerWritesOfObject: object)
        }
    }


    private func forEachDelegate(f: (SwimListManagerDelegate -> ())) {
        SwimAssertOnMainThread()

        delegates.forEach {
            f($0 as! SwimListManagerDelegate)
        }
    }


    private func handleFailures(task: BFTask) -> BFTask {
        if let err = task.error {
            log.warning("Operation failed: \(err).")
            sendDidReceiveError(err)
        }
        if let exn = task.exception {
            log.warning("Operation failed: \(exn).")
            let err = SwimError.Unknown
            sendDidReceiveError(err)
        }
        return task
    }

    private func logFailures(task: BFTask) -> BFTask {
        if let err = task.error {
            log.warning("Operation failed: \(err).")
        }
        if let exn = task.exception {
            log.warning("Operation failed: \(exn).")
        }
        return task
    }
}


private func didCompleteServerWrite<ObjectType: SwimModelProtocolBase>(object: ObjectType, manager: SwimListManager<ObjectType>?, task: BFTask) -> BFTask {
    dispatch_async(dispatch_get_main_queue()) {
        precondition(object.serverWritesInProgress > 0)
        object.serverWritesInProgress -= 1
        if object.serverWritesInProgress == 0 {
            manager?.sendDidCompleteServerWrites(object)
        }
    }
    return task
}
