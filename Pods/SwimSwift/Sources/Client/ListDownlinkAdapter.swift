import Bolts
import Recon


private let log = SwimLogging.log


class ListDownlinkAdapter: SynchedDownlinkAdapter, ListDownlink {
    var state = [SwimValue]()
    var objects = [SwimModelProtocolBase]()

    private let objectMaker: (SwimValue -> SwimModelProtocolBase?)


    init(downlink: Downlink, objectMaker: (SwimValue -> SwimModelProtocolBase?)) {
        self.objectMaker = objectMaker
        super.init(downlink: downlink)
        uplink = self
    }


    override func swimDownlink(downlink: Downlink, events messages: [EventMessage]) {
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
                guard let index = header["index"].integer else {
                    log.warning("Received insert with no index!")
                    return
                }
                let body = message.body.dropFirst()
                remoteInsert(body, atIndex: index)

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

        super.swimDownlink(downlink, events: messages)
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

        guard let object = objectMaker(value) else {
            log.warning("Ignoring update with unparseable value!")
            return false
        }

        if index == state.count {
            state.append(value)
            objects.append(object)
            forEachListDelegate {
                $0.swimListDownlink($1, didInsert: [object], atIndexes: [index])
            }
        }
        else {
            state[index] = value
            let existingObject = objects[index]
            existingObject.swim_updateWithSwimValue(value)
            forEachListDelegate {
                $0.swimListDownlink($1, didUpdate: existingObject, atIndex: index)
            }
        }

        return true
    }


    func remoteInsert(value: SwimValue, atIndex index: Int) -> Bool {
        SwimAssertOnMainThread()
        precondition(state.count == objects.count)

        let swimId = value["swimId"].text ?? ""
        if objects.indexOf({ $0.swimId == swimId }) != nil {
            log.verbose("Ignoring insert of object that we already have (it's hopefully one that we just inserted).")
            return false
        }

        guard 0 <= index && index <= state.count else {
            log.warning("Ignoring insert out of range!")
            return false
        }

        guard let object = swimValueToObject(value) else {
            log.warning("Ignoring insert with unparseable item!")
            return false
        }

        if index < state.count && state[index] == value {
            log.warning("Ignoring duplicate insert!")
            return false
        }

        state.insert(value, atIndex: index)
        objects.insert(object, atIndex: index)

        forEachListDelegate {
            $0.swimListDownlink($1, didInsert: [object], atIndexes: [index])
        }

        return true
    }


    /**
     This is only intended for the initial load e.g. from the local
     database.  It doesn't handle conflicts with existing items already in
     this list (it assumes that this list is empty right now).
     */
    func loadValues(values: [SwimValue]) {
        guard count == 0 else {
            log.verbose("Refusing to load; we already have some content")
            return
        }

        let newObjects = values.flatMap({ objectMaker($0) })
        if newObjects.count != values.count {
            log.warning("Ignoring loadValues with unparseable item!")
            return
        }

        sendWillChangeObjects()

        state = values
        objects = newObjects

        let indexes = [Int](0 ..< values.count)
        forEachListDelegate {
            $0.swimListDownlink($1, didInsert: self.objects, atIndexes: indexes)
        }

        sendDidChangeObjects()
    }


    func remoteMove(value: SwimValue, fromIndex from: Int, toIndex to: Int) -> Bool {
        SwimAssertOnMainThread()
        precondition(state.count == objects.count)

        if state[to] == value {
            log.verbose("Ignoring duplicate move \(value)")
            return false
        }

        guard let newDestObject = swimValueToObject(value) else {
            log.warning("Ignoring move with invalid object! \(value)")
            return false
        }

        let oldDestObject = objects[to]
        log.verbose("Moving \(from) -> \(to): \(oldDestObject) -> \(newDestObject)")

        state.removeAtIndex(from)
        state.insert(value, atIndex: to)
        let object = objects.removeAtIndex(from)
        objects.insert(object, atIndex: to)

        forEachListDelegate {
            $0.swimListDownlink($1, didMove: object, fromIndex: from, toIndex: to)
        }

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

        forEachListDelegate {
            $0.swimListDownlink($1, didRemove: object, atIndex: index)
        }

        return true
    }


    func remoteRemoveAll() {
        SwimAssertOnMainThread()
        precondition(state.count == self.objects.count)

        let objects = self.objects
        self.state.removeAll()
        self.objects.removeAll()
        forEachListDelegate {
            $0.swimListDownlinkDidRemoveAll($1, objects: objects)
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

        let object = objects[index]
        object.serverWritesInProgress += 1

        let task = sendCommand("update", value: value, index: index).continueWithBlock { [weak self] task in
            return didCompleteServerWrite(object, downlink: self, task: task)
        }.continueWithBlock { [weak self] task in
            return self?.handleFailures(task)
        }

        state[index] = value
        objects[index].swim_updateWithSwimValue(value)
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
        precondition(!object.swimId.isEmpty)
        precondition(index >= 0)
        precondition(index <= objects.count)

        if laneProperties.isClientReadOnly {
            return BFTask(swimError: .DownlinkIsClientReadOnly)
        }

        log.verbose("Inserted object at \(index): \(object)")

        object.serverWritesInProgress += 1
        let task = sendCommand("insert", value: value, index: index).continueWithBlock { [weak self] task in
            return didCompleteServerWrite(object, downlink: self, task: task)
        }.continueWithBlock { [weak self] task in
            return self?.handleFailures(task)
        }

        objects.insert(object, atIndex: index)
        state.insert(value, atIndex: index)

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

        return sendCommand("move", value: value, from: from, to: to).continueWithBlock { [weak self] task in
            return self?.handleFailures(task)
        }
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

        let task = sendCommand("remove", value: value, index: index).continueWithBlock { [weak self] task in
            return self?.handleFailures(task)
        }

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

        return command(body: SwimValue(Item.Attr("clear"))).continueWithBlock { [weak self] task in
            return self?.handleFailures(task)
        }
    }


    func setHighlightAtIndex(index: Int, isHighlighted: Bool) -> BFTask {
        SwimAssertOnMainThread()
        precondition(state.count == objects.count)

        if laneProperties.isClientReadOnly {
            return BFTask(swimError: .DownlinkIsClientReadOnly)
        }

        let object = objects[index]
        let cmd = (isHighlighted ? "highlight" : "unhighlight")
        log.verbose("Did \(cmd) \(index): \(object)")

        object.isHighlighted = isHighlighted
        return updateObjectAtIndex(index)
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

    override func sendSyncRequest() {
        preconditionFailure("You do not need to call this, this list is automatically synched.")
    }

    func sendWillChangeObjects() {
        SwimAssertOnMainThread()

        forEachListDelegate {
            $0.swimListDownlinkWillChangeObjects($1)
        }
    }

    func sendDidChangeObjects() {
        SwimAssertOnMainThread()

        forEachListDelegate {
            $0.swimListDownlinkDidChangeObjects($1)
        }
    }


    func forEachListDelegate(f: (ListDownlinkDelegate, ListDownlink) -> ()) {
        forEachDelegate { [weak self] (delegate, _) in
            guard let delegate = delegate as? ListDownlinkDelegate, downlink = self as? ListDownlink else {
                return
            }
            f(delegate, downlink)
        }
    }


    private func swimValueToObject(value: SwimValue) -> SwimModelProtocolBase? {
        return objectMaker(value)
    }
}


private func bodyWithCommand(command: String, value: SwimValue, indexValue: SwimValue) -> SwimValue {
    let body = Record()
    body.append(Item.Attr(command, indexValue))
    body["item"] = value
    return Value(body)
}


private func didCompleteServerWrite(object: SwimModelProtocolBase, downlink: ListDownlinkAdapter?, task: BFTask) -> BFTask {
    dispatch_async(dispatch_get_main_queue()) {
        precondition(object.serverWritesInProgress > 0)
        object.serverWritesInProgress -= 1
        if object.serverWritesInProgress == 0 {
            downlink?.sendDidCompleteServerWrites(object)
        }
    }
    return task
}
