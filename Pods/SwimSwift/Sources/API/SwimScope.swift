public protocol SwimScope {
    func scope(host host: SwimUri) -> HostScope

    func scope(host host: SwimUri, node: SwimUri) -> NodeScope

    func scope(host host: SwimUri, node: SwimUri, lane: SwimUri) -> LaneScope

    func scope(node node: SwimUri) -> NodeScope

    func scope(node node: SwimUri, lane: SwimUri) -> LaneScope

    func downlink() -> DownlinkBuilder

    func link(host host: SwimUri, node: SwimUri, lane: SwimUri, prio: Double) -> Downlink

    func link(node node: SwimUri, lane: SwimUri, prio: Double) -> Downlink

    func sync(host host: SwimUri, node: SwimUri, lane: SwimUri, prio: Double) -> Downlink

    func sync(node node: SwimUri, lane: SwimUri, prio: Double) -> Downlink

    func syncList(host host: SwimUri, node: SwimUri, lane: SwimUri, prio: Double) -> ListDownlink

    func syncList(node node: SwimUri, lane: SwimUri, prio: Double) -> ListDownlink

    func syncMap(host host: SwimUri, node: SwimUri, lane: SwimUri, prio: Double, primaryKey: SwimValue -> SwimValue) -> MapDownlink

    func syncMap(node node: SwimUri, lane: SwimUri, prio: Double, primaryKey: SwimValue -> SwimValue) -> MapDownlink

    func command(host host: SwimUri, node: SwimUri, lane: SwimUri, body: SwimValue)

    func command(node node: SwimUri, lane: SwimUri, body: SwimValue)

    func auth(host host: SwimUri, credentials: SwimValue)

    func close()
}

public extension SwimScope {
    public func link(host host: SwimUri, node: SwimUri, lane: SwimUri) -> Downlink {
        return link(host: host, node: node, lane: lane, prio: 0.0)
    }

    public func link(node node: SwimUri, lane: SwimUri) -> Downlink {
        return link(node: node, lane: lane, prio: 0.0)
    }

    public func sync(host host: SwimUri, node: SwimUri, lane: SwimUri) -> Downlink {
        return sync(host: host, node: node, lane: lane, prio: 0.0)
    }

    public func sync(node node: SwimUri, lane: SwimUri) -> Downlink {
        return sync(node: node, lane: lane, prio: 0.0)
    }

    public func syncList(host host: SwimUri, node: SwimUri, lane: SwimUri) -> ListDownlink {
        return syncList(host: host, node: node, lane: lane, prio: 0.0)
    }

    public func syncList(node node: SwimUri, lane: SwimUri) -> ListDownlink {
        return syncList(node: node, lane: lane, prio: 0.0)
    }

    public func syncMap(host host: SwimUri, node: SwimUri, lane: SwimUri, primaryKey: SwimValue -> SwimValue) -> MapDownlink {
        return syncMap(host: host, node: node, lane: lane, prio: 0.0, primaryKey: primaryKey)
    }

    public func syncMap(node node: SwimUri, lane: SwimUri, primaryKey: SwimValue -> SwimValue) -> MapDownlink {
        return syncMap(node: node, lane: lane, prio: 0.0, primaryKey: primaryKey)
    }
}
