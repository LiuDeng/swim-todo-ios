import Recon


private let log = SwimLogging.log


class RemoteListDownlink: RemoteSyncedDownlink, ListDownlink {
    private var state = [Value]()
    var objects = [SwimModelProtocolBase]()

    private let objectMaker: (SwimValue -> SwimModelProtocolBase?)

    private var listDownlinkDelegate: ListDownlinkDelegate? {
        return delegate as? ListDownlinkDelegate
    }

    init(channel: Channel, scope: RemoteScope?, host: SwimUri, node: SwimUri, lane: SwimUri, prio: Double, objectMaker: (SwimValue -> SwimModelProtocolBase?)) {
        self.objectMaker = objectMaker
        super.init(channel: channel, scope: scope, host: host, node: node, lane: lane, prio: prio)
    }

    override func onEventMessages(messages: [EventMessage]) {
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

        super.onEventMessages(messages)
    }

    func remoteAppend(value: Value) {
        remoteInsert(value, atIndex: state.count)
    }

    func remoteUpdate(value: Value, atIndex index: Int) {
        SwimAssertOnMainThread()
        precondition(state.count == objects.count)

        let item = value["item"]
        guard let object = objectMaker(item) else {
            log.warning("Received update with unparseable item!")
            return
        }

        if 0 <= index && index < state.count {
            state[index] = value
            let existingObject = objects[index]
            existingObject.swim_updateWithSwimValue(item)
            if let delegate = listDownlinkDelegate {
                delegate.downlink(self, didUpdate: existingObject, atIndex: index)
            }
        }
        else {
            let index = state.count
            state.append(value)
            objects.append(object)
            if let delegate = listDownlinkDelegate {
                delegate.downlink(self, didInsert: object, atIndex: index)
            }
        }
    }

    func remoteInsert(value: Value, atIndex index: Int) {
        SwimAssertOnMainThread()
        precondition(state.count == objects.count)

        let item = value["item"]
        guard let object = objectMaker(item) else {
            log.warning("Received insert with unparseable item!")
            return
        }

        if 0 <= index && index <= state.count && state[index] != value {
            state.insert(value, atIndex: index)
            objects.insert(object, atIndex: index)

            if let delegate = listDownlinkDelegate {
                delegate.downlink(self, didInsert: object, atIndex: index)
            }
        }
        else if index > state.count {
            let index = state.count
            state.append(value)
            objects.append(object)

            if let delegate = listDownlinkDelegate {
                delegate.downlink(self, didInsert: object, atIndex: index)
            }
        }
        else {
            log.warning("Received insert that we cannot handle!")
        }
    }

    func remoteMove(value: Value, fromIndex from: Int, toIndex to: Int) {
        SwimAssertOnMainThread()
        precondition(state.count == objects.count)

        if state[to] == value {
            log.verbose("Ignoring duplicate move \(value)")
            return
        }

        let item = value["item"]
        guard let newDestObject = objectMaker(item) else {
            log.warning("Ignoring move with invalid object! \(item)")
            return
        }

        let oldDestObject = objects[to]
        log.verbose("Moving \(from) -> \(to): \(oldDestObject) -> \(newDestObject)")

        state.removeAtIndex(from)
        state.insert(value, atIndex: to)
        let object = objects.removeAtIndex(from)
        objects.insert(object, atIndex: to)

        if let delegate = listDownlinkDelegate {
            delegate.downlink(self, didMove: object, fromIndex: from, toIndex: to)
        }
    }

    func remoteRemove(value: Value, atIndex index: Int) {
        SwimAssertOnMainThread()
        precondition(state.count == objects.count)

        if state[index] != value {
            log.verbose("Ignoring remove, presumably this was a local change")
            return
        }

        state.removeAtIndex(index)
        let object = objects.removeAtIndex(index)

        if let delegate = listDownlinkDelegate {
            delegate.downlink(self, didRemove: object, atIndex: index)
        }
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
        set(obj) {
            SwimAssertOnMainThread()
            precondition(state.count == objects.count)
            
            let value = obj.swim_toSwimValue()
            let body = bodyWithCommand("update", item: value, index: index)
            channel.command(node: nodeUri, lane: laneUri, body: body)

            state[index] = value
            objects[index].swim_updateWithSwimValue(value)
        }
    }

    func updateObjectAtIndex(index: Int) {
        SwimAssertOnMainThread()

        let object = objects[index]
        log.verbose("Updated \(index): \(object)")
        self[index] = object
    }

    func insert(object: SwimModelProtocolBase, atIndex index: Int) {
        SwimAssertOnMainThread()
        precondition(state.count == objects.count)

        log.verbose("Inserted object at \(index): \(object)")

        let value = object.swim_toSwimValue()
        let body = bodyWithCommand("insert", item: value, index: index)
        channel.command(node: nodeUri, lane: laneUri, body: body)

        // We're not inserting into objects right now -- we're waiting for it to come back from the server instead.
        // TODO: This is a dirty hack and needs fixing properly.  We need a sessionId on messages so that we don't
        // respond to our own.
//        objects.insert(object, atIndex: index)
//        state.insert(value, atIndex: index)
    }

    func moveFromIndex(from: Int, toIndex to: Int) {
        SwimAssertOnMainThread()
        precondition(state.count == objects.count)

        let value = state.removeAtIndex(from)
        state.insert(value, atIndex: to)
        let object = objects.removeAtIndex(from)
        objects.insert(object, atIndex: to)

        log.verbose("Moved \(from) -> \(to): \(object)")

        let body = bodyWithCommand("move", item: value, from: from, to: to)
        channel.command(node: nodeUri, lane: laneUri, body: body)
    }

    func removeAtIndex(index: Int) -> SwimModelProtocolBase {
        SwimAssertOnMainThread()
        precondition(state.count == objects.count)

        let value = state.removeAtIndex(index)
        let object = objects.removeAtIndex(index)

        log.verbose("Removed object at \(index)")

        let body = bodyWithCommand("remove", item: value, index: index)
        channel.command(node: nodeUri, lane: laneUri, body: body)

        return object
    }

    func removeAll() {
        SwimAssertOnMainThread()
        precondition(state.count == objects.count)

        state.removeAll()
        objects.removeAll()

        let body = Value(Item.Attr("clear"))
        channel.command(node: nodeUri, lane: laneUri, body: body)
    }

    private func sendWillChangeObjects() {
        SwimAssertOnMainThread()

        if let delegate = listDownlinkDelegate {
            delegate.downlinkWillChangeObjects(self)
        }
    }

    private func sendDidChangeObjects() {
        SwimAssertOnMainThread()

        if let delegate = listDownlinkDelegate {
            delegate.downlinkDidChangeObjects(self)
        }
    }
}


private func bodyWithCommand(command: String, item: SwimValue, index: Int) -> Value {
    let indexValue = Value(Slot("index", Value(index)))
    return bodyWithCommand(command, item: item, indexValue: indexValue)
}

private func bodyWithCommand(command: String, item: SwimValue, from: Int, to: Int) -> Value {
    let indexValue = Value(Slot("from", Value(from)), Slot("to", Value(to)))
    return bodyWithCommand(command, item: item, indexValue: indexValue)
}

private func bodyWithCommand(command: String, item: SwimValue, indexValue: Value) -> Value {
    var body = Record()
    body.append(Item.Attr(command, indexValue))
    body.append(Slot("item", item))
    return Value(body)
}
