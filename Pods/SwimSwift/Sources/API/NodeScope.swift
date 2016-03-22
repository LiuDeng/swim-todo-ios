/**
 Facilitates the creation and management of downlinks to a single service instance.
 */
public protocol NodeScope {

    /// The URI of the network endpoint to which the scope is bound.
    var hostUri: SwimUri { get }

    /// The URI of the service to which the scope is bound. An absolute URI resolved against `hostUri`.
    var nodeUri: SwimUri { get }

    /**
     - returns: A new `LaneScope` bound to the given `lane` URI of the service to which this scope is bound.

     ```swift
        let chat = client.scope(node: "ws://swim.example.com/chat/public")
        let chatRoom = chat.scope(lane: "chat/room")
     ```
     */
    func scope(lane lane: SwimUri) -> LaneScope

    /**
     - returns: A new `DownlinkBuilder`, used to construct a link to a lane of the service node to which this scope is bound.

     ```swift
        let chat = client.scope(node: "ws://swim.example.com/chat/public")
        let messages = chat.downlink()
            .lane("chat/room")
            .syncList()
     ```
     */
    func downlink() -> DownlinkBuilder

    func link(lane lane: SwimUri, prio: Double) -> Downlink

    func sync(lane lane: SwimUri, prio: Double) -> Downlink

    func syncList(lane lane: SwimUri, prio: Double) -> ListDownlink

    func syncMap(lane lane: SwimUri, prio: Double, primaryKey: SwimValue -> SwimValue) -> MapDownlink

    /**
     Sends a command to a lane of the service to which this scope is bound.

     ```swift
        let chat = client.scope(node: "ws://swim.example.com/chat/public")
        chat.command(lane: "chat/room", body: "Hello, world!")
     ```
     */
    func command(lane lane: SwimUri, body: SwimValue)

    /// Unlinks all downlinks registered with the scope.
    func close()
}

public extension NodeScope {
    public func link(lane lane: SwimUri) -> Downlink {
        return link(lane: lane, prio: 0.0)
    }

    public func sync(lane laneUri: SwimUri) -> Downlink {
        return sync(lane: laneUri, prio: 0.0)
    }

    public func syncList(lane laneUri: SwimUri) -> ListDownlink {
        return syncList(lane: laneUri, prio: 0.0)
    }

    public func syncMap(lane lane: SwimUri, primaryKey: SwimValue -> SwimValue) -> MapDownlink {
        return syncMap(lane: lane, prio: 0.0, primaryKey: primaryKey)
    }
}
