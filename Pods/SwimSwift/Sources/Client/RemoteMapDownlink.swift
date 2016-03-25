import Recon

class RemoteMapDownlink: RemoteSyncedDownlink, MapDownlink {
    var state: [SwimValue: SwimValue] = [SwimValue: SwimValue]()

    var primaryKey: SwimValue -> SwimValue

    init(channel: Channel, scope: RemoteScope?, host: SwimUri, node: SwimUri, lane: SwimUri, prio: Double, primaryKey: SwimValue -> SwimValue) {
        self.primaryKey = primaryKey
        super.init(channel: channel, scope: scope, host: host, node: node, lane: lane, prio: prio)
    }

    override func onEventMessages(messages: [EventMessage]) {
        for message in messages {
            switch message.body.tag {
            case "remove"?, "delete"?:
                let body = message.body.dropFirst()
                let key = primaryKey(body)
                if key.isDefined {
                    remoteRemoveValueForKey(key)
                }
            case "clear"? where message.body.record?.count == 1:
                remoteRemoveAll()
            default:
                let key = primaryKey(message.body)
                if key.isDefined {
                    remoteUpdateValue(message.body, forKey: key)
                }
            }
        }
        super.onEventMessages(messages)
    }

    func remoteUpdateValue(value: SwimValue, forKey key: SwimValue) {
        state[key] = value
        if case let delegate as MapDownlinkDelegate = self.delegate {
            delegate.downlink(self, didUpdate: value, forKey: key)
        }
    }

    func remoteRemoveValueForKey(key: SwimValue) {
        if let value = state.removeValueForKey(key), case let delegate as MapDownlinkDelegate = self.delegate {
            delegate.downlink(self, didRemove: value, forKey: key)
        }
    }

    func remoteRemoveAll() {
        let state = self.state
        self.state.removeAll()
        if case let delegate as MapDownlinkDelegate = self.delegate {
            for case (let key, let value) in state {
                delegate.downlink(self, didRemove: value, forKey: key)
            }
        }
    }

    var isEmpty: Bool {
        return state.isEmpty
    }

    var count: Int {
        return state.count
    }

    subscript(key: SwimValue) -> SwimValue {
        get {
            return state[key] ?? SwimValue.Absent
        }
        set(value) {
            updateValue(value, forKey: key)
        }
    }

    func updateValue(value: SwimValue, forKey key: SwimValue) -> SwimValue? {
        let oldValue = state.updateValue(value, forKey: key)
        let nodeUri = channel.unresolve(self.nodeUri)
        let message = CommandMessage(node: nodeUri, lane: laneUri, body: value)
        onCommandMessages([message])
        channel.push(envelope: message)
        return oldValue
    }

    func removeValueForKey(key: SwimValue) -> SwimValue? {
        if let oldValue = state.removeValueForKey(key) {
            let nodeUri = channel.unresolve(self.nodeUri)
            var body = Record()
            body.append(Item.Attr("remove"))
            if let oldRecord = oldValue.record {
                body.appendContentsOf(oldRecord)
            } else {
                body.append(Item.Value(oldValue))
            }
            let message = CommandMessage(node: nodeUri, lane: laneUri, body: SwimValue(body))
            onCommandMessages([message])
            channel.push(envelope: message)
            return oldValue
        } else {
            return nil
        }
    }

    func removeAll() {
        state.removeAll()
        let nodeUri = channel.unresolve(self.nodeUri)
        let body = SwimValue(Item.Attr("clear"))
        let message = CommandMessage(node: nodeUri, lane: laneUri, body: body)
        onCommandMessages([message])
        channel.push(envelope: message)
    }

    func forEach(f: (SwimValue, SwimValue) throws -> ()) rethrows {
        return try state.forEach(f)
    }
}
