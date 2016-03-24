/**
 Facilitates the creation and management of downlinks to a single network endpoint.
 */
public protocol HostScope {

    /**
     - returns: A new `NodeScope` bound to the service at the given `node` URI on the network endpoint to which this scope is bound.

     ```swift
        let host = client.scope(host: "ws://swim.example.com")
        let chat = host.scope(node: "/chat/public")
     ```
     */
    func scope(node node: SwimUri) -> NodeScope

    /**
     - returns: A new `LaneScope` bound to the `lane` URI of the given `node` URI on the network endpoint to which this scope is bound.

     ```swift
        let host = client.scope(host: "ws://swim.example.com")
        let chatRoom = host.scope(node: "/chat/public", lane: "chat/room")
     ```
     */
    func scope(node node: SwimUri, lane: SwimUri) -> LaneScope

    /**
     - returns: A new `DownlinkBuilder`, used to construct a link to a lane of a service node on the network endpoint to which this scope is bound.

     ```swift
        let host = client.scope(host: "ws://swim.example.com")
        let link = host.downlink()
            .node("/chat/public")
            .lane("chat/room")
            .sync()
     ```
     */
    func downlink() -> DownlinkBuilder

    func link(node node: SwimUri, lane: SwimUri, prio: Double) -> Downlink

    func sync(node node: SwimUri, lane: SwimUri, prio: Double) -> Downlink

    func syncList(node node: SwimUri, lane: SwimUri, prio: Double) -> ListDownlink

    func syncMap(node node: SwimUri, lane: SwimUri, prio: Double, primaryKey: SwimValue -> SwimValue) -> MapDownlink

    /**
     Sends a command to a lane of a service node on the network endpoint to which this scope is bound.

     ```swift
        let host = client.scope(host: "ws://swim.example.com")
        host.command(node: "/chat/public", lane: "chat/room", body: "Hello, world!")
     ```
     */
    func command(node node: SwimUri, lane: SwimUri, body: SwimValue)

    /// Unlinks all downlinks registered with the scope.
    func close()
}

public extension HostScope {
    public func link(node node: SwimUri, lane: SwimUri) -> Downlink {
        return link(node: node, lane: lane, prio: 0.0)
    }

    public func sync(node node: SwimUri, lane: SwimUri) -> Downlink {
        return sync(node: node, lane: lane, prio: 0.0)
    }

    public func syncList(node node: SwimUri, lane: SwimUri) -> ListDownlink {
        return syncList(node: node, lane: lane, prio: 0.0)
    }

    public func syncMap(node node: SwimUri, lane: SwimUri, primaryKey: SwimValue -> SwimValue) -> MapDownlink {
        return syncMap(node: node, lane: lane, prio: 0.0, primaryKey: primaryKey)
    }
}
