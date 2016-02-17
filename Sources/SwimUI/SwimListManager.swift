//
//  SwimListManager.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 2/15/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import Foundation
import Recon
import Swim


public protocol SwimListManagerProtocol: class {
    var delegate: SwimListManagerDelegate? { get set }
    var objects: [AnyObject] { get }
    var nodeScope: NodeScope? { get set }

    func startSynching()
    func stopSynching()
    func moveObjectAtIndex(fromIndex: Int, toIndex: Int)
    func removeObjectAtIndex(index: Int)
    func setHighlightAtIndex(index: Int, isHighlighted: Bool)
}

@objc public protocol SwimListManagerDelegate: class {
    optional func swimDidAppend(object: AnyObject)
    optional func swimDidMove(fromIndex: Int, toIndex: Int)
    optional func swimDidRemove(index: Int, object: AnyObject)
    optional func swimDidReplace(index: Int, object: AnyObject)
    optional func swimDidSetHighlight(index: Int, isHighlighted: Bool)
    optional func swimDidStartSynching()
    optional func swimDidStopSynching()
}


public class SwimListManager<ObjectType: SwimModelProtocol>: SwimListManagerProtocol {
    public weak var delegate: SwimListManagerDelegate? = nil

    public var objects: [AnyObject] = []

    public var nodeScope: NodeScope? = nil

    let laneUri: Uri

    var downLink: DownlinkRef? = nil

    public init(laneUri: Uri) {
        self.laneUri = laneUri
    }

    public func startSynching() {
        guard let ns = nodeScope else {
            return
        }

        downLink = ns.sync(lane: laneUri)
        guard var dl = downLink else {
            DLog("Failed to create downLink!")
            return
        }

        dl.keepAlive = true
        dl.event = didReceiveEvent

        delegate?.swimDidStartSynching?()
    }

    public func stopSynching() {
        guard let ns = nodeScope else {
            return
        }
        ns.close()
        nodeScope = nil

        delegate?.swimDidStopSynching?()
    }

    public func moveObjectAtIndex(fromIndex: Int, toIndex: Int) {
        guard let ns = nodeScope else {
            return
        }

        let object = objects.removeAtIndex(fromIndex)
        objects.insert(object, atIndex: toIndex)
        DLog("Moved \(fromIndex) -> \(toIndex): \(object)")

        ns.command(lane: laneUri, body: Value(Attr("move", Value(Slot("from", Value(fromIndex)), Slot("to", Value(toIndex))))))
    }

    public func removeObjectAtIndex(index: Int) {
        guard let ns = nodeScope else {
            return
        }

        objects.removeAtIndex(index)
        DLog("Deleted object at \(index)")

        ns.command(lane: laneUri, body: Value(Attr("remove", Value(Slot("index", Value(index))))))
    }

    public func setHighlightAtIndex(index: Int, isHighlighted: Bool) {
        guard let ns = nodeScope else {
            return
        }

        let object = objects[index] as! ObjectType
        let item = object.toReconValue()
        let cmd = (isHighlighted ? "highlight" : "unhighlight")
        DLog("Did \(cmd) \(index): \(object)")

        if isHighlighted {
            ns.command(lane: laneUri, body: Value(Attr("update", Value(Slot("index", Value(index)))), Slot("item", item), Slot("highlight", Value.True)))
        }
        else {
            ns.command(lane: laneUri, body: Value(Attr("update", Value(Slot("index", Value(index)))), Slot("item", item)))
        }
    }

    func didReceiveEvent(message: EventMessage) {
        DLog("Did receive \(message)")

        let heading = message.body.first
        switch heading.key?.text {
        case "insert"?:
            break

        case "update"?:
            didReceiveUpdate(message)

        case "move"?:
            didReceiveMove(message)

        case "remove"?:
            didReceiveRemove(message)

        default:
            didReceiveAppend(message)
        }
    }

    func didReceiveAppend(message: EventMessage) {
        guard let object = ObjectType(reconValue: message.body["item"]) else {
            DLog("Received append with unparseable item!")
            return
        }

        objects.append(object)
        delegate?.swimDidAppend?(object)
    }

    func didReceiveUpdate(message: EventMessage) {
        let heading = message.body.first
        let item = message.body["item"]
        guard let index = heading.value["index"].number else {
            DLog("Received update with no index!")
            return
        }

        let idx = Int(index)
        let objectOrNil = ObjectType(reconValue: item)

        if let object = objectOrNil {
            if idx == objects.count {
                objects.append(object)
                delegate?.swimDidAppend?(object)
            }
            else if idx > objects.count {
                DLog("Ignoring update referring to rows beyond our list! \(heading.value)")
                return
            }
            else {
                DLog("Replacing item at \(idx): \(object)")
                let oldObject = objects[idx] as! ObjectType
                oldObject.update(item)

                delegate?.swimDidReplace?(idx, object: object)
            }
        }

        let isHighlighted = (message.body["highlight"] == Value.True)
        DLog("Highlight \(idx) = \(isHighlighted)")
        delegate?.swimDidSetHighlight?(idx, isHighlighted: isHighlighted)
    }

    func didReceiveMove(message: EventMessage) {
        let heading = message.body.first
        guard
            let from = heading.value["from"].number,
            let to = heading.value["to"].number else {
                DLog("Received move with no from or to index!")
                return
        }

        let fromIndex = Int(from)
        let toIndex = Int(to)
        let oldDestObject = objects[toIndex] as! ObjectType
        guard let newDestObject = ObjectType(reconValue: message.body["item"]) else {
            DLog("Ignoring move with invalid object! \(heading.value)")
            return
        }
        DLog("Moving \(fromIndex) -> \(toIndex): \(oldDestObject) -> \(newDestObject)")

        if oldDestObject == newDestObject {
            DLog("Ignoring duplicate move \(heading.value)")
            return
        }

        let object = objects.removeAtIndex(fromIndex)
        objects.insert(object, atIndex: toIndex)
        delegate?.swimDidMove?(fromIndex, toIndex: toIndex)
    }

    func didReceiveRemove(message: EventMessage) {
        let heading = message.body.first
        guard let index = heading.value["index"].number else {
            DLog("Received remove with no index!")
            return
        }

        let idx = Int(index)
        let oldObject = objects[idx] as! ObjectType
        guard let removedObject = ObjectType(reconValue: message.body["item"]) else {
            DLog("Ignoring remove with invalid object! \(heading.value)")
            return
        }

        if oldObject != removedObject {
            DLog("Ignoring remove, presumably this was a local change")
            return
        }

        let object = objects.removeAtIndex(idx)
        assert(oldObject === object)
        delegate?.swimDidRemove?(idx, object: object)
    }
}
