import Recon


private let log = SwimLogging.log


class RemoteListDownlink: RemoteSyncedDownlink, ListDownlink {
    var state: [Value] = [Value]()

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
        let index = state.count
        state.append(value)
        if case let delegate as ListDownlinkDelegate = self.delegate {
            delegate.downlink(self, didInsert: value, atIndex: index)
        }
    }

    func remoteUpdate(value: Value, atIndex index: Int) {
        if 0 <= index && index < state.count {
            state[index] = value
            if case let delegate as ListDownlinkDelegate = self.delegate {
                delegate.downlink(self, didUpdate: value, atIndex: index)
            }
        } else {
            let index = state.count
            state.append(value)
            if case let delegate as ListDownlinkDelegate = self.delegate {
                delegate.downlink(self, didInsert: value, atIndex: index)
            }
        }
    }

    func remoteInsert(value: Value, atIndex index: Int) {
        if 0 <= index && index <= state.count && state[index] != value {
            state.insert(value, atIndex: index)
            if case let delegate as ListDownlinkDelegate = self.delegate {
                delegate.downlink(self, didInsert: value, atIndex: index)
            }
        } else if index > state.count {
            let index = state.count
            state.append(value)
            if case let delegate as ListDownlinkDelegate = self.delegate {
                delegate.downlink(self, didInsert: value, atIndex: index)
            }
        }
        else {
            log.warning("Received insert that we cannot handle!")
        }
    }

    func remoteMove(value: Value, fromIndex from: Int, toIndex to: Int) {
        if state[to] != value {
            state.removeAtIndex(from)
            state.insert(value, atIndex: to)
            if case let delegate as ListDownlinkDelegate = self.delegate {
                delegate.downlink(self, didMove: value, fromIndex: from, toIndex: to)
            }
        }
    }

    func remoteRemove(value: Value, atIndex index: Int) {
        if state[index] == value {
            state.removeAtIndex(index)
            if case let delegate as ListDownlinkDelegate = self.delegate {
                delegate.downlink(self, didRemove: value, atIndex: index)
            }
        }
    }

    func remoteRemoveAll() {
        let state = self.state
        self.state.removeAll()
        if case let delegate as ListDownlinkDelegate = self.delegate {
            for index in (0 ..< state.count).reverse() {
                delegate.downlink(self, didRemove: state[count], atIndex: index)
            }
        }
    }

    var isEmpty: Bool {
        return state.isEmpty
    }

    var count: Int {
        return state.count
    }

    subscript(index: Int) -> Value {
        get {
            return state[index]
        }
        set(value) {
            state[index] = value
            var body = Record()
            body.append(Item.Attr("update", Value(Slot("index", Value(index)))))
            if let record = value.record {
                body.appendContentsOf(record)
            } else {
                body.append(Item.Value(value))
            }
            channel.command(node: nodeUri, lane: laneUri, body: Value(body))
        }
    }

    var first: Value? {
        return state.first
    }

    var last: Value? {
        return state.last
    }

    func append(value: Value) {
        state.append(value)
        channel.command(node: nodeUri, lane: laneUri, body: value)
    }

    func insert(value: Value, atIndex index: Int) {
        state.insert(value, atIndex: index)
        var body = Record()
        body.append(Item.Attr("insert", Value(Slot("index", Value(index)))))
        if let record = value.record {
            body.appendContentsOf(record)
        } else {
            body.append(Item.Value(value))
        }
        channel.command(node: nodeUri, lane: laneUri, body: Value(body))
    }

    func moveFromIndex(from: Int, toIndex to: Int) {
        let value = state.removeAtIndex(from)
        state.insert(value, atIndex: to)
        var body = Record()
        body.append(Item.Attr("move", Value(Slot("from", Value(from)), Slot("to", Value(to)))))
        if let record = value.record {
            body.appendContentsOf(record)
        } else {
            body.append(Item.Value(value))
        }
        channel.command(node: nodeUri, lane: laneUri, body: Value(body))
    }

    func removeAtIndex(index: Int) -> Value {
        let value = state.removeAtIndex(index)
        var body = Record()
        body.append(Item.Attr("remove", Value(Slot("index", Value(index)))))
        if let record = value.record {
            body.appendContentsOf(record)
        } else {
            body.append(Item.Value(value))
        }
        channel.command(node: nodeUri, lane: laneUri, body: Value(body))
        return value
    }

    func removeAll() {
        state.removeAll()
        let body = Value(Item.Attr("clear"))
        channel.command(node: nodeUri, lane: laneUri, body: body)
    }

    func popLast() -> Value? {
        if let value = state.popLast() {
            let index = state.count
            var body = Record()
            body.append(Item.Attr("remove", Value(Slot("index", Value(index)))))
            if let record = value.record {
                body.appendContentsOf(record)
            } else {
                body.append(Item.Value(value))
            }
            channel.command(node: nodeUri, lane: laneUri, body: Value(body))
            return value
        } else {
            return nil
        }
    }

    func removeLast() -> Value {
        let value = state.removeLast()
        let index = state.count
        var body = Record()
        body.append(Item.Attr("remove", Value(Slot("index", Value(index)))))
        if let record = value.record {
            body.appendContentsOf(record)
        } else {
            body.append(Item.Value(value))
        }
        channel.command(node: nodeUri, lane: laneUri, body: Value(body))
        return value
    }

    func forEach(f: Value throws -> ()) rethrows {
        try state.forEach(f)
    }

    func sendWillChangeObjects() {
        if let delegate = delegate as? ListDownlinkDelegate {
            delegate.downlinkWillChangeObjects(self)
        }
    }

    func sendDidChangeObjects() {
        if let delegate = delegate as? ListDownlinkDelegate {
            delegate.downlinkDidChangeObjects(self)
        }
    }
}
