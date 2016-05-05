//
//  MapDownlinkAdapter.swift
//  Swim
//
//  Created by Ewan Mellor on 4/29/16.
//
//

import Foundation
import Bolts
import Recon


private let log = SwimLogging.log


class MapDownlinkAdapter: SynchedDownlinkAdapter, MapDownlink {
    var state: [SwimValue: SwimValue] = [SwimValue: SwimValue]()
    var objects = [SwimValue: SwimModelProtocolBase]()

    private let objectMaker: (SwimValue -> SwimModelProtocolBase?)

    private let primaryKey: (SwimModelProtocolBase -> SwimValue)


    init(downlink: Downlink, objectMaker: (SwimValue -> SwimModelProtocolBase?), primaryKey: (SwimModelProtocolBase -> SwimValue)) {
        self.objectMaker = objectMaker
        self.primaryKey = primaryKey
        super.init(downlink: downlink)
        uplink = self
    }


    subscript(key: SwimValue) -> SwimModelProtocolBase? {
        get {
            SwimAssertOnMainThread()
            return objects[key]
        }
    }


    override func swimDownlink(downlink: Downlink, events messages: [EventMessage]) {
        log.verbose("Did receive \(messages)")

        sendWillChange()

        for message in messages {
            switch message.body.tag {
            case "remove"?, "delete"?:
                let body = message.body.dropFirst()
                guard let obj = objectMaker(body) else {
                    log.warning("Ignoring remove for unparseable item! \(body)")
                    return
                }
                let key = primaryKey(obj)
                if key.isDefined {
                    remoteRemoveValueForKey(key)
                }
            case "clear"? where message.body.record?.count == 1:
                remoteRemoveAll()

            default:
                guard let obj = objectMaker(message.body) else {
                    log.warning("Ignoring update for unparseable item! \(message.body)")
                    return
                }
                let key = primaryKey(obj)
                if key.isDefined {
                    remoteUpdateValue(message.body, forKey: key)
                }
            }
        }

        sendDidChange()

        super.swimDownlink(downlink, events: messages)
    }


    func remoteUpdateValue(value: SwimValue, forKey key: SwimValue) -> Bool {
        SwimAssertOnMainThread()
        precondition(state.count == objects.count)

        let item = value["item"]
        guard let newObject = objectMaker(item) else {
            log.warning("Ignoring update with unparseable item!")
            return false
        }

        state[key] = value
        if let existingObject = objects[key] {
            existingObject.swim_updateWithSwimValue(item)
            forEachMapDelegate {
                $0.swimMapDownlink($1, didUpdate: existingObject, forKey: key)
            }
        }
        else {
            objects[key] = newObject
            forEachMapDelegate {
                $0.swimMapDownlink($1, didSet: newObject, forKey: key)
            }
        }

        return true
    }


    func remoteRemoveValueForKey(key: SwimValue) -> Bool {
        SwimAssertOnMainThread()
        precondition(state.count == objects.count)

        guard objects[key] != nil else {
            log.verbose("Ignoring remove for missing item, presumably this was a local change")
            return false
        }

        state.removeValueForKey(key)
        let object = objects.removeValueForKey(key)!

        forEachMapDelegate {
            $0.swimMapDownlink($1, didRemove: object, forKey: key)
        }

        return true
    }


    func remoteRemoveAll() {
        SwimAssertOnMainThread()
        precondition(state.count == self.objects.count)

        let objects = self.objects
        self.state.removeAll()
        self.objects.removeAll()
        forEachMapDelegate {
            $0.swimMapDownlinkDidRemoveAll($1, objects: objects)
        }
    }


    var isEmpty: Bool {
        SwimAssertOnMainThread()
        return objects.isEmpty
    }

    var count: Int {
        SwimAssertOnMainThread()
        return objects.count
    }


    func updateObjectForKey(key: SwimValue) -> BFTask {
        SwimAssertOnMainThread()

        if laneProperties.isClientReadOnly {
            return BFTask(swimError: .DownlinkIsClientReadOnly)
        }

        guard let object = objects[key] else {
            return BFTask(swimError: .NoSuchKey)
        }
        log.verbose("Updated \(key): \(object)")
        return setObject(object, forKey: key)
    }


    func setObject(object: SwimModelProtocolBase, forKey key: SwimValue) -> BFTask {
        return setObject(object, value: wrapValueAsItem(object.swim_toSwimValue()), forKey: key)
    }

    func setObject(object: SwimModelProtocolBase, value: SwimValue, forKey key: SwimValue) -> BFTask {
        SwimAssertOnMainThread()
        precondition(state.count == objects.count)
        precondition(!object.swimId.isEmpty)
        precondition(objects[key] != nil)

        if laneProperties.isClientReadOnly {
            return BFTask(swimError: .DownlinkIsClientReadOnly)
        }

        log.verbose("objects[\(key)] = \(object)")

        let task = command(body: value)

        objects[key] = object
        state[key] = value

        return task
    }

    func removeObjectForKey(key: SwimValue) -> (SwimModelProtocolBase?, BFTask) {
        SwimAssertOnMainThread()
        precondition(state.count == objects.count)

        if laneProperties.isClientReadOnly {
            return (nil, BFTask(swimError: .DownlinkIsClientReadOnly))
        }

        guard let value = state.removeValueForKey(key) else {
            log.verbose("Key \(key) not present")
            return (nil, BFTask(result: nil))
        }

        let object = objects.removeValueForKey(key)!

        log.verbose("Removed object for \(key)")

        let task = sendCommand("remove", value: value)

        return (object, task)
    }

    func removeAll() -> BFTask {
        SwimAssertOnMainThread()
        precondition(state.count == objects.count)

        if laneProperties.isClientReadOnly {
            return BFTask(swimError: .DownlinkIsClientReadOnly)
        }

        state.removeAll()
        objects.removeAll()

        return command(body: SwimValue(Item.Attr("clear")))
    }

    private func wrapValueAsItem(value: SwimValue) -> SwimValue {
        return SwimValue(Slot("item", value))
    }

    private func sendCommand(cmd: String, value: SwimValue) -> BFTask {
        return command(body: bodyWithCommand(cmd, value: value))
    }

    override func sendSyncRequest() -> BFTask {
        preconditionFailure("You do not need to call this, this list is automatically synched.")
    }

    func sendWillChange() {
        SwimAssertOnMainThread()

        forEachMapDelegate {
            $0.swimMapDownlinkWillChange($1)
        }
    }

    func sendDidChange() {
        SwimAssertOnMainThread()

        forEachMapDelegate {
            $0.swimMapDownlinkDidChange($1)
        }
    }


    func forEachMapDelegate(f: (MapDownlinkDelegate, MapDownlink) -> ()) {
        forEachDelegate { [weak self] (delegate, _) in
            guard let delegate = delegate as? MapDownlinkDelegate, downlink = self as? MapDownlink else {
                return
            }
            f(delegate, downlink)
        }
    }


    private func swimValueToObject(value: SwimValue) -> SwimModelProtocolBase? {
        let item = value["item"]
        return objectMaker(item)
    }
}


private func bodyWithCommand(command: String, value: SwimValue) -> SwimValue {
    let body = Record()
    body["item"] = value["item"]
    return Value(body)
}
