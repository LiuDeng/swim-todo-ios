import Bolts
import Recon


private let log = SwimLogging.log


class ListDownlinkAdapter: SynchedDownlinkAdapter, ListDownlink, Hashable {
    var state = [SwimValue]()
    var objects = [SwimModelProtocolBase]()

    private let objectMaker: (SwimValue -> SwimModelProtocolBase?)

    var listDownlinkDelegate: ListDownlinkDelegate? {
        return delegate as? ListDownlinkDelegate
    }


    init(downlink: Downlink, objectMaker: (SwimValue -> SwimModelProtocolBase?)) {
        self.objectMaker = objectMaker
        super.init(downlink: downlink)
        uplink = self
    }


    override func downlink(downlink: Downlink, events messages: [EventMessage]) {
        log.verbose("Did receive \(messages)")

        sendWillChangeObjects()

        for message in messages {
            switch message.body.tag {
            case "update"?:
                let header = message.body.first.value
                if let index = header["index"].integer {
                    let body = message.body.dropFirst()
                    remoteUpdate(body, atIndex: index)
                }
                else {
                    log.warning("Received update with no index!")
                }

            case "insert"?:
                let header = message.body.first.value
                if let index = header["index"].integer {
                    let body = message.body.dropFirst()
                    remoteInsert(body, atIndex: index)
                }
                else {
                    log.warning("Received insert with no index!")
                }

            case "move"?:
                let header = message.body.first.value
                if let from = header["from"].integer, let to = header["to"].integer {
                    let body = message.body.dropFirst()
                    remoteMove(body, fromIndex: from, toIndex: to)
                }
                else {
                    log.warning("Received move without from or to index!")
                }

            case "remove"?, "delete"?:
                let header = message.body.first.value
                if let index = header["index"].integer {
                    let body = message.body.dropFirst()
                    remoteRemove(body, atIndex: index)
                }
                else {
                    log.warning("Received \(message.body.tag) with no index!")
                }

            case "clear"?:
                if message.body.record?.count == 1 {
                    remoteRemoveAll()
                }
                else {
                    log.warning("Received clear with invalid body!")
                }

            default:  // TODO: Check for "append" as a command here?
                remoteAppend(message.body)
            }
        }

        sendDidChangeObjects()

        super.downlink(downlink, events: messages)
    }


    private func remoteAppend(value: SwimValue) -> Bool {
        return remoteInsert(value, atIndex: state.count)
    }


    func remoteUpdate(value: SwimValue, atIndex index: Int) -> Bool {
        SwimAssertOnMainThread()
        precondition(state.count == objects.count)

        guard 0 <= index && index <= state.count else {
            log.warning("Ignoring update out of range!")
            return false
        }

        let item = value["item"]
        guard let object = objectMaker(item) else {
            log.warning("Ignoring update with unparseable item!")
            return false
        }

        if index == state.count {
            state.append(value)
            objects.append(object)
            listDownlinkDelegate?.downlink(self, didInsert: object, atIndex: index)
        }
        else {
            state[index] = value
            let existingObject = objects[index]
            existingObject.swim_updateWithSwimValue(item)
            listDownlinkDelegate?.downlink(self, didUpdate: existingObject, atIndex: index)
        }

        return true
    }


    func remoteInsert(value: SwimValue, atIndex index: Int) -> Bool {
        SwimAssertOnMainThread()
        precondition(state.count == objects.count)

        guard 0 <= index && index <= state.count else {
            log.warning("Ignoring insert out of range!")
            return false
        }

        let item = value["item"]
        guard let object = objectMaker(item) else {
            log.warning("Ignoring insert with unparseable item!")
            return false
        }

        if index < state.count && state[index] == value {
            log.warning("Ignoring duplicate insert!")
            return false
        }

        state.insert(value, atIndex: index)
        objects.insert(object, atIndex: index)

        listDownlinkDelegate?.downlink(self, didInsert: object, atIndex: index)

        return true
    }


    func remoteMove(value: SwimValue, fromIndex from: Int, toIndex to: Int) -> Bool {
        SwimAssertOnMainThread()
        precondition(state.count == objects.count)

        if state[to] == value {
            log.verbose("Ignoring duplicate move \(value)")
            return false
        }

        let item = value["item"]
        guard let newDestObject = objectMaker(item) else {
            log.warning("Ignoring move with invalid object! \(item)")
            return false
        }

        let oldDestObject = objects[to]
        log.verbose("Moving \(from) -> \(to): \(oldDestObject) -> \(newDestObject)")

        state.removeAtIndex(from)
        state.insert(value, atIndex: to)
        let object = objects.removeAtIndex(from)
        objects.insert(object, atIndex: to)

        listDownlinkDelegate?.downlink(self, didMove: object, fromIndex: from, toIndex: to)

        return true
    }


    func remoteRemove(value: SwimValue, atIndex index: Int) -> Bool {
        SwimAssertOnMainThread()
        precondition(state.count == objects.count)

        guard 0 <= index && index < state.count else {
            log.verbose("Ignoring remove out of range, presumably this was a local change at the end of the list")
            return false
        }

        if state[index] != value {
            log.verbose("Ignoring remove, presumably this was a local change")
            return false
        }

        state.removeAtIndex(index)
        let object = objects.removeAtIndex(index)

        listDownlinkDelegate?.downlink(self, didRemove: object, atIndex: index)

        return true
    }


    func remoteRemoveAll() {
        SwimAssertOnMainThread()
        precondition(state.count == self.objects.count)

        let objects = self.objects
        self.state.removeAll()
        self.objects.removeAll()
        if let delegate = listDownlinkDelegate {
            for index in (0 ..< objects.count).reverse() {
                delegate.downlink(self, didRemove: objects[count], atIndex: index)
            }
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


    subscript(index: Int) -> SwimModelProtocolBase {
        get {
            SwimAssertOnMainThread()
            return objects[index]
        }
    }


    func replace(object: SwimModelProtocolBase, atIndex index: Int) -> BFTask {
        return replace(wrapValueAsItem(object.swim_toSwimValue()), atIndex: index)
    }

    func replace(value: SwimValue, atIndex index: Int) -> BFTask {
        SwimAssertOnMainThread()
        precondition(state.count == objects.count)

        if laneProperties.isClientReadOnly {
            return BFTask(swimError: .DownlinkIsClientReadOnly)
        }

        log.verbose("Replaced \(index): \(value)")

        let task = sendCommand("update", value: value, index: index)

        let item = value["item"]
        state[index] = value
        objects[index].swim_updateWithSwimValue(item)
        return task
    }

    func updateObjectAtIndex(index: Int) -> BFTask {
        SwimAssertOnMainThread()

        if laneProperties.isClientReadOnly {
            return BFTask(swimError: .DownlinkIsClientReadOnly)
        }

        let object = objects[index]
        log.verbose("Updated \(index): \(object)")
        return replace(object, atIndex: index)
    }

    func insert(object: SwimModelProtocolBase, atIndex index: Int) -> BFTask {
        return insert(object, value: wrapValueAsItem(object.swim_toSwimValue()), atIndex: index)
    }

    func insert(object: SwimModelProtocolBase, value: SwimValue, atIndex index: Int) -> BFTask {
        SwimAssertOnMainThread()
        precondition(state.count == objects.count)

        if laneProperties.isClientReadOnly {
            return BFTask(swimError: .DownlinkIsClientReadOnly)
        }

        log.verbose("Inserted object at \(index): \(object)")

        let task = sendCommand("insert", value: value, index: index)

        // We're not inserting into objects right now -- we're waiting for it to come back from the server instead.
        // TODO: This is a dirty hack and needs fixing properly.  We need a sessionId on messages so that we don't
        // respond to our own.
//        objects.insert(object, atIndex: index)
//        state.insert(value, atIndex: index)

        return task
    }

    func moveFromIndex(from: Int, toIndex to: Int) -> BFTask {
        SwimAssertOnMainThread()
        precondition(state.count == objects.count)

        if laneProperties.isClientReadOnly {
            return BFTask(swimError: .DownlinkIsClientReadOnly)
        }

        let value = state.removeAtIndex(from)
        state.insert(value, atIndex: to)
        let object = objects.removeAtIndex(from)
        objects.insert(object, atIndex: to)

        log.verbose("Moved \(from) -> \(to): \(object)")

        return sendCommand("move", value: value, from: from, to: to)
    }

    func removeAtIndex(index: Int) -> (SwimModelProtocolBase?, BFTask) {
        SwimAssertOnMainThread()
        precondition(state.count == objects.count)

        if laneProperties.isClientReadOnly {
            return (nil, BFTask(swimError: .DownlinkIsClientReadOnly))
        }

        let value = state.removeAtIndex(index)
        let object = objects.removeAtIndex(index)

        log.verbose("Removed object at \(index)")

        let task = sendCommand("remove", value: value, index: index)

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

    private func sendCommand(cmd: String, value: SwimValue, index: Int) -> BFTask {
        let indexValue = Value(Slot("index", Value(index)))
        return command(body: bodyWithCommand(cmd, value: value, indexValue: indexValue))
    }

    private func sendCommand(cmd: String, value: SwimValue, from: Int, to: Int) -> BFTask {
        let indexValue = Value(Slot("from", Value(from)), Slot("to", Value(to)))
        return command(body: bodyWithCommand(cmd, value: value, indexValue: indexValue))
    }

    private func sendCommand(cmd: String, value: SwimValue, indexValue: SwimValue) -> BFTask {
        return command(body: bodyWithCommand(cmd, value: value, indexValue: indexValue))
    }

    override func sendSyncRequest() -> BFTask {
        preconditionFailure("You do not need to call this, this list is automatically synched.")
    }

    func sendWillChangeObjects() {
        SwimAssertOnMainThread()

        listDownlinkDelegate?.downlinkWillChangeObjects(self)
    }

    func sendDidChangeObjects() {
        SwimAssertOnMainThread()

        listDownlinkDelegate?.downlinkDidChangeObjects(self)
    }


    var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
}


private func bodyWithCommand(command: String, value: SwimValue, indexValue: SwimValue) -> SwimValue {
    let body = Record()
    body.append(Item.Attr(command, indexValue))
    body["item"] = value["item"]
    return Value(body)
}


func == (lhs: ListDownlinkAdapter, rhs: ListDownlinkAdapter) -> Bool {
    return lhs === rhs
}
