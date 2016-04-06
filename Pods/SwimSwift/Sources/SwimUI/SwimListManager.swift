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
    var objects: [AnyObject] { get }
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

    func swimDidInsert(object: AnyObject, atIndex: Int)
    func swimDidMove(fromIndex: Int, toIndex: Int)
    func swimDidRemove(index: Int, object: AnyObject)
    func swimDidReplace(index: Int, object: AnyObject)

    func swimDidSetHighlight(index: Int, isHighlighted: Bool)

    func swimDidStartSynching()
    func swimDidStopSynching()

    func swimDidLink()
    func swimDidUnlink()
}

public extension SwimListManagerDelegate {
    public func swimWillChangeObjects() {}
    public func swimDidChangeObjects() {}

    public func swimDidInsert(object: AnyObject, atIndex: Int) {}
    public func swimDidMove(fromIndex: Int, toIndex: Int) {}
    public func swimDidRemove(index: Int, object: AnyObject) {}
    public func swimDidReplace(index: Int, object: AnyObject) {}

    public func swimDidSetHighlight(index: Int, isHighlighted: Bool) {}

    public func swimDidStartSynching() {}
    public func swimDidStopSynching() {}

    public func swimDidLink() {}
    public func swimDidUnlink() {}
}


public class SwimListManager<ObjectType: SwimModelProtocol>: SwimListManagerProtocol, ListDownlinkDelegate {
    private var delegates = WeakArray<AnyObject>()

    public var objects: [AnyObject] = []

    public var laneScope: LaneScope? = nil

    private var downLink: ListDownlink? = nil

    public init() {
    }

    public func addDelegate(delegate: SwimListManagerDelegate) {
        delegates.append(delegate)
    }

    public func removeDelegate(delegate: SwimListManagerDelegate) {
        delegates.remove(delegate)
    }

    public func startSynching() {
        guard let ls = laneScope else {
            return
        }

        downLink = ls.syncList()
        guard var dl = downLink else {
            log.warning("Failed to create downLink!")
            return
        }

        dl.keepAlive = true
        dl.delegate = self

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
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
        guard let dl = downLink else {
            return nil
        }

        let object = ObjectType()
        let item = Value(Slot("item", object.swim_toSwimValue()))
        // We're not inserting into objects right now -- we're waiting for it to come back from the server instead.
        // TODO: This is a dirty hack and needs fixing properly.  We need a sessionId on messages so that we don't
        // respond to our own.
//        objects.insert(object, atIndex: index)
        log.verbose("Inserted new object at \(index)")

        dl.insert(item, atIndex: index)

        return object
    }

    public func moveObjectAtIndex(fromIndex: Int, toIndex: Int) {
        guard let dl = downLink else {
            return
        }

        let object = objects.removeAtIndex(fromIndex)
        objects.insert(object, atIndex: toIndex)
        log.verbose("Moved \(fromIndex) -> \(toIndex): \(object)")

        dl.moveFromIndex(fromIndex, toIndex: toIndex)
    }

    public func removeObjectAtIndex(index: Int) {
        guard let dl = downLink else {
            return
        }

        objects.removeAtIndex(index)
        log.verbose("Deleted object at \(index)")

        dl.removeAtIndex(index)
    }

    public func setHighlightAtIndex(index: Int, isHighlighted: Bool) {
        guard var dl = downLink else {
            return
        }

        let object = objects[index] as! ObjectType
        let cmd = (isHighlighted ? "highlight" : "unhighlight")
        log.verbose("Did \(cmd) \(index): \(object)")

        let objectValue = object.swim_toSwimValue()
        if isHighlighted {
            dl[index] = Value(Slot("item", objectValue), Slot("highlight", Value.True))
        }
        else {
            dl[index] = Value(Slot("item", objectValue))
        }
    }

    public func updateObjectAtIndex(index: Int) {
        guard var dl = downLink else {
            return
        }

        let object = objects[index] as! ObjectType
        log.verbose("Updated \(index): \(object)")

        dl[index] = Value(Slot("item", object.swim_toSwimValue()))
    }

    public func downlink(_: ListDownlink, didInsert value: SwimValue, atIndex index: Int) {
        let item = value["item"]
        guard let object = ObjectType(swimValue: item) else {
            log.warning("Received insert with unparseable item!")
            preconditionFailure("Recovery from this is unimplemented")
        }

        objects.insert(object, atIndex: index)

        forEachDelegate {
            $0.swimDidInsert(object, atIndex: index)
        }
    }

    public func downlink(_: ListDownlink, didUpdate value: SwimValue, atIndex index: Int) {
        precondition(index < objects.count)

        let item = value["item"]
        let objectOrNil = ObjectType(swimValue: item)
        if let object = objectOrNil {
            log.verbose("Replacing item at \(index): \(object)")
            let oldObject = objects[index] as! ObjectType
            oldObject.swim_updateWithSwimValue(item)

            forEachDelegate {
                $0.swimDidReplace(index, object: object)
            }
        }

        let isHighlighted = (value["highlight"] == Value.True)
        log.verbose("Highlight \(index) = \(isHighlighted)")

        forEachDelegate {
            $0.swimDidSetHighlight(index, isHighlighted: isHighlighted)
        }
    }

    public func downlink(_: ListDownlink, didMove value: SwimValue, fromIndex: Int, toIndex: Int) {
        let oldDestObject = objects[toIndex] as! ObjectType
        let item = value["item"]
        guard let newDestObject = ObjectType(swimValue: item) else {
            log.warning("Ignoring move with invalid object! \(item)")
            preconditionFailure("Recovery from this is unimplemented")
        }
        log.verbose("Moving \(fromIndex) -> \(toIndex): \(oldDestObject) -> \(newDestObject)")

        if oldDestObject == newDestObject {
            log.verbose("Ignoring duplicate move \(item)")
            return
        }

        let object = objects.removeAtIndex(fromIndex)
        objects.insert(object, atIndex: toIndex)

        forEachDelegate {
            $0.swimDidMove(fromIndex, toIndex: toIndex)
        }
    }

    public func downlink(_: ListDownlink, didRemove value: SwimValue, atIndex index: Int) {
        let oldObject = objects[index] as! ObjectType
        let item = value["item"]
        guard let removedObject = ObjectType(swimValue: item) else {
            log.info("Ignoring remove with invalid object! \(item)")
            preconditionFailure("Recovery from this is unimplemented")
        }

        if oldObject != removedObject {
            log.verbose("Ignoring remove, presumably this was a local change")
            preconditionFailure("Recovery from this is unimplemented")
        }

        let object = objects.removeAtIndex(index)
        precondition(oldObject === object)

        forEachDelegate {
            $0.swimDidRemove(index, object: object)
        }
    }

    public func downlinkWillChangeObjects(downlink: Downlink) {
        forEachDelegate {
            $0.swimWillChangeObjects()
        }
    }

    public func downlinkDidChangeObjects(downlink: Downlink) {
        forEachDelegate {
            $0.swimDidChangeObjects()
        }
    }

    public func downlink(downlink: Downlink, didLink response: LinkedResponse) {
        forEachDelegate {
            $0.swimDidLink()
        }
    }

    public func downlink(downlink: Downlink, didUnlink response: UnlinkedResponse) {
        forEachDelegate {
            $0.swimDidUnlink()
        }
    }


    private func forEachDelegate(f: (SwimListManagerDelegate -> ())) {
        precondition(NSThread.isMainThread())

        delegates.forEach {
            f($0 as! SwimListManagerDelegate)
        }
    }
}
