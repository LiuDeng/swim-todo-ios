import Recon

class RemoteListDownlink: RemoteSyncedDownlink, ListDownlink {
    var state: [Value] = [Value]()

    override func onEventMessages(messages: [EventMessage]) {
        for message in messages {
            switch message.body.tag {
            case "update"?:
                let header = message.body.first.value
                if let index = header["index"].integer {
                    let body = message.body.dropFirst()
                    remoteUpdate(body, atIndex: index)
                }
            case "insert"?:
                let header = message.body.first.value
                if let index = header["index"].integer {
                    let body = message.body.dropFirst()
                    remoteInsert(body, atIndex: index)
                }
            case "move"?:
                let header = message.body.first.value
                if let from = header["from"].integer, let to = header["to"].integer {
                    let body = message.body.dropFirst()
                    remoteMove(body, fromIndex: from, toIndex: to)
                }
            case "remove"?, "delete"?:
                let header = message.body.first.value
                if let index = header["index"].integer {
                    let body = message.body.dropFirst()
                    remoteRemove(body, atIndex: index)
                }
            case "clear"? where message.body.record?.count == 1:
                remoteRemoveAll()
            default:
                remoteAppend(message.body)
            }
        }
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
            let nodeUri = channel.unresolve(self.nodeUri)
            var body = Record()
            body.append(Item.Attr("update", Value(Slot("index", Value(index)))))
            if let record = value.record {
                body.appendContentsOf(record)
            } else {
                body.append(Item.Value(value))
            }
            let message = CommandMessage(node: nodeUri, lane: laneUri, body: Value(body))
            onCommandMessage(message)
            channel.push(envelope: message)
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
        let nodeUri = channel.unresolve(self.nodeUri)
        let message = CommandMessage(node: nodeUri, lane: laneUri, body: value)
        onCommandMessage(message)
        channel.push(envelope: message)
    }

    func insert(value: Value, atIndex index: Int) {
        state.insert(value, atIndex: index)
        let nodeUri = channel.unresolve(self.nodeUri)
        var body = Record()
        body.append(Item.Attr("insert", Value(Slot("index", Value(index)))))
        if let record = value.record {
            body.appendContentsOf(record)
        } else {
            body.append(Item.Value(value))
        }
        let message = CommandMessage(node: nodeUri, lane: laneUri, body: Value(body))
        onCommandMessage(message)
        channel.push(envelope: message)
    }

    func moveFromIndex(from: Int, toIndex to: Int) {
        let value = state.removeAtIndex(from)
        state.insert(value, atIndex: to)
        let nodeUri = channel.unresolve(self.nodeUri)
        var body = Record()
        body.append(Item.Attr("move", Value(Slot("from", Value(from)), Slot("to", Value(to)))))
        if let record = value.record {
            body.appendContentsOf(record)
        } else {
            body.append(Item.Value(value))
        }
        let message = CommandMessage(node: nodeUri, lane: laneUri, body: Value(body))
        onCommandMessage(message)
        channel.push(envelope: message)
    }

    func removeAtIndex(index: Int) -> Value {
        let value = state.removeAtIndex(index)
        let nodeUri = channel.unresolve(self.nodeUri)
        var body = Record()
        body.append(Item.Attr("remove", Value(Slot("index", Value(index)))))
        if let record = value.record {
            body.appendContentsOf(record)
        } else {
            body.append(Item.Value(value))
        }
        let message = CommandMessage(node: nodeUri, lane: laneUri, body: Value(body))
        onCommandMessage(message)
        channel.push(envelope: message)
        return value
    }

    func removeAll() {
        state.removeAll()
        let nodeUri = channel.unresolve(self.nodeUri)
        let body = Value(Item.Attr("clear"))
        let message = CommandMessage(node: nodeUri, lane: laneUri, body: body)
        onCommandMessage(message)
        channel.push(envelope: message)
    }

    func popLast() -> Value? {
        if let value = state.popLast() {
            let index = state.count
            let nodeUri = channel.unresolve(self.nodeUri)
            var body = Record()
            body.append(Item.Attr("remove", Value(Slot("index", Value(index)))))
            if let record = value.record {
                body.appendContentsOf(record)
            } else {
                body.append(Item.Value(value))
            }
            let message = CommandMessage(node: nodeUri, lane: laneUri, body: Value(body))
            onCommandMessage(message)
            channel.push(envelope: message)
            return value
        } else {
            return nil
        }
    }

    func removeLast() -> Value {
        let value = state.removeLast()
        let index = state.count
        let nodeUri = channel.unresolve(self.nodeUri)
        var body = Record()
        body.append(Item.Attr("remove", Value(Slot("index", Value(index)))))
        if let record = value.record {
            body.appendContentsOf(record)
        } else {
            body.append(Item.Value(value))
        }
        let message = CommandMessage(node: nodeUri, lane: laneUri, body: Value(body))
        onCommandMessage(message)
        channel.push(envelope: message)
        return value
    }

    func forEach(f: Value throws -> ()) rethrows {
        try state.forEach(f)
    }
}
