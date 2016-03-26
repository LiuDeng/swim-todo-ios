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
    var nodeScope: NodeScope? { get set }

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

    In other words, this indicates the start of a batch of calls to swimDid{Append,Insert,Move,Remove,Replace}.
     */
    func swimWillChangeObjects()

    /**
     Will be called after a batch of changes to SwimListManagerProtocol.objects has been processed.

     In other words, this indicates the end of a batch of calls to swimDid{Append,Insert,Move,Remove,Replace}.
     */
    func swimDidChangeObjects()

    func swimDidAppend(object: AnyObject)
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

    public func swimDidAppend(object: AnyObject) {}
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


public class SwimListManager<ObjectType: SwimModelProtocol>: SwimListManagerProtocol, DownlinkDelegate {
    private var delegates = WeakArray<AnyObject>()

    public var objects: [AnyObject] = []

    public var nodeScope: NodeScope? = nil

    let laneUri: SwimUri

    var downLink: Downlink? = nil

    public init(laneUri: SwimUri) {
        self.laneUri = laneUri
    }

    public func addDelegate(delegate: SwimListManagerDelegate) {
        delegates.append(delegate)
    }

    public func removeDelegate(delegate: SwimListManagerDelegate) {
        delegates.remove(delegate)
    }

    public func startSynching() {
        guard let ns = nodeScope else {
            return
        }

        downLink = ns.sync(lane: laneUri)
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
        guard let ns = nodeScope else {
            return
        }
        ns.close()
        nodeScope = nil

        forEachDelegate {
            $0.swimDidStopSynching()
        }
    }

    public func insertNewObjectAtIndex(index: Int) -> Any? {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
        guard let ns = nodeScope else {
            return nil
        }

        let object = ObjectType()
        let item = object.swim_toSwimValue()
        // We're not inserting into objects right now -- we're waiting for it to come back from the server instead.
        // TODO: This is a dirty hack and needs fixing properly.  We need a sessionId on messages so that we don't
        // respond to our own.
//        objects.insert(object, atIndex: index)
        log.verbose("Inserted new object at \(index)")

        ns.command(lane: laneUri, body: Value(Attr("insert", Value(Slot("index", Value(index)), Slot("item", item)))))

        return object
    }

    public func moveObjectAtIndex(fromIndex: Int, toIndex: Int) {
        guard let ns = nodeScope else {
            return
        }

        let object = objects.removeAtIndex(fromIndex)
        objects.insert(object, atIndex: toIndex)
        log.verbose("Moved \(fromIndex) -> \(toIndex): \(object)")

        ns.command(lane: laneUri, body: Value(Attr("move", Value(Slot("from", Value(fromIndex)), Slot("to", Value(toIndex))))))
    }

    public func removeObjectAtIndex(index: Int) {
        guard let ns = nodeScope else {
            return
        }

        objects.removeAtIndex(index)
        log.verbose("Deleted object at \(index)")

        ns.command(lane: laneUri, body: Value(Attr("remove", Value(Slot("index", Value(index))))))
    }

    public func setHighlightAtIndex(index: Int, isHighlighted: Bool) {
        guard let ns = nodeScope else {
            return
        }

        let object = objects[index] as! ObjectType
        let item = object.swim_toSwimValue()
        let cmd = (isHighlighted ? "highlight" : "unhighlight")
        log.verbose("Did \(cmd) \(index): \(object)")

        if isHighlighted {
            ns.command(lane: laneUri, body: Value(Attr("update", Value(Slot("index", Value(index)))), Slot("item", item), Slot("highlight", Value.True)))
        }
        else {
            ns.command(lane: laneUri, body: Value(Attr("update", Value(Slot("index", Value(index)))), Slot("item", item)))
        }
    }

    public func updateObjectAtIndex(index: Int) {
        // TODO: It's a complete fluke that setHighlightAtIndex:isHighlighted=false happens
        // to do exactly what we want.  Tidy this up.
        setHighlightAtIndex(index, isHighlighted: false)
    }

    public func downlink(downlink: Downlink, events: [EventMessage]) {
        log.verbose("Did receive \(events)")

        sendWillChangeObjects()

        for message in events {
            let heading = message.body.first
            switch heading.key?.text {
            case "insert"?:
                didReceiveInsert(message)

            case "update"?:
                didReceiveUpdate(message)

            case "move"?:
                didReceiveMove(message)

            case "remove"?:
                didReceiveRemove(message)

            default:  // TODO: Check for "append" as a command here?
                didReceiveAppend(message)
            }
        }

        sendDidChangeObjects()
    }

    func didReceiveInsert(message: EventMessage) {
        let heading = message.body.first
        let item = message.body["item"]
        guard let index = heading.value["index"].number else {
            log.warning("Received insert with no index!")
            return
        }
        guard let object = ObjectType(swimValue: item) else {
            log.warning("Received insert with unparseable item!")
            return
        }

        let idx = Int(index)
        objects.insert(object, atIndex: idx)

        forEachDelegate {
            $0.swimDidInsert(object, atIndex: idx)
        }
    }

    func didReceiveAppend(message: EventMessage) {
        let item = message.body["item"]
        guard let object = ObjectType(swimValue: item) else {
            log.warning("Received append with unparseable item!")
            return
        }

        objects.append(object)

        forEachDelegate {
            $0.swimDidAppend(object)
        }
    }

    func didReceiveUpdate(message: EventMessage) {
        let heading = message.body.first
        let item = message.body["item"]
        guard let index = heading.value["index"].number else {
            log.warning("Received update with no index!")
            return
        }

        let idx = Int(index)
        let objectOrNil = ObjectType(swimValue: item)

        if let object = objectOrNil {
            if idx == objects.count {
                objects.append(object)

                forEachDelegate {
                    $0.swimDidAppend(object)
                }
            }
            else if idx > objects.count {
                log.warning("Ignoring update referring to rows beyond our list! \(heading.value)")
                return
            }
            else {
                log.verbose("Replacing item at \(idx): \(object)")
                let oldObject = objects[idx] as! ObjectType
                oldObject.swim_updateWithSwimValue(item)

                forEachDelegate {
                    $0.swimDidReplace(idx, object: object)
                }
            }
        }

        let isHighlighted = (message.body["highlight"] == Value.True)
        log.verbose("Highlight \(idx) = \(isHighlighted)")

        forEachDelegate {
            $0.swimDidSetHighlight(idx, isHighlighted: isHighlighted)
        }
    }

    func didReceiveMove(message: EventMessage) {
        let heading = message.body.first
        guard
            let from = heading.value["from"].number,
            let to = heading.value["to"].number else {
                log.warning("Received move with no from or to index!")
                return
        }

        let fromIndex = Int(from)
        let toIndex = Int(to)
        let oldDestObject = objects[toIndex] as! ObjectType
        guard let newDestObject = ObjectType(swimValue: message.body["item"]) else {
            log.warning("Ignoring move with invalid object! \(heading.value)")
            return
        }
        log.verbose("Moving \(fromIndex) -> \(toIndex): \(oldDestObject) -> \(newDestObject)")

        if oldDestObject == newDestObject {
            log.verbose("Ignoring duplicate move \(heading.value)")
            return
        }

        let object = objects.removeAtIndex(fromIndex)
        objects.insert(object, atIndex: toIndex)

        forEachDelegate {
            $0.swimDidMove(fromIndex, toIndex: toIndex)
        }
    }

    func didReceiveRemove(message: EventMessage) {
        let heading = message.body.first
        guard let index = heading.value["index"].number else {
            log.warning("Received remove with no index!")
            return
        }

        let idx = Int(index)
        let oldObject = objects[idx] as! ObjectType
        guard let removedObject = ObjectType(swimValue: message.body["item"]) else {
            log.info("Ignoring remove with invalid object! \(heading.value)")
            return
        }

        if oldObject != removedObject {
            log.verbose("Ignoring remove, presumably this was a local change")
            return
        }

        let object = objects.removeAtIndex(idx)
        assert(oldObject === object)

        forEachDelegate {
            $0.swimDidRemove(idx, object: object)
        }
    }

    func sendWillChangeObjects() {
        forEachDelegate {
            $0.swimWillChangeObjects()
        }
    }

    func sendDidChangeObjects() {
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
        delegates.forEach {
            f($0 as! SwimListManagerDelegate)
        }
    }
}
