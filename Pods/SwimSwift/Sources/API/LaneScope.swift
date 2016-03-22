/**
 Facilitates the creation and management of downlinks to a single lane of some service instance.
 */
public protocol LaneScope {

    /// The URI of the network endpoint to which the scope is bound.
    var hostUri: SwimUri { get }

    /// The URI of the service to which the scope is bound. An absolute URI resolved against `hostUri`.
    var nodeUri: SwimUri { get }

    /// The URI of the lane to which the scope is bound.
    var laneUri: SwimUri { get }

    /**
     - returns: A new `DownlinkBuilder`, used to construct a link to a lane of the service node to which this scope is bound.

     ```swift
        let chatRoom = client.scope(node: "ws://swim.example.com/chat/public", lane: "chat/room")
        let messages = chat.downlink().syncList()
     ```
     */
    func downlink() -> DownlinkBuilder

    func link(prio prio: Double) -> Downlink

    func sync(prio prio: Double) -> Downlink

    func syncList(prio prio: Double) -> ListDownlink

    func syncMap(prio prio: Double, primaryKey: SwimValue -> SwimValue) -> MapDownlink

    /**
     Sends a command to the remote lane to which this scope is bound.

     ```swift
        let chat = client.scope(node: "ws://swim.example.com/chat/public", lane: "chat/room")
        chat.command(body: "Hello, world!")
     ```
     */
    func command(body body: SwimValue)

    /// Unlinks all downlinks registered with the scope.
    func close()
}

public extension LaneScope {
    public func link() -> Downlink {
        return link(prio: 0.0)
    }

    public func sync() -> Downlink {
        return sync(prio: 0.0)
    }

    func syncList() -> ListDownlink {
        return syncList(prio: 0.0)
    }

    public func syncMap(primaryKey primaryKey: SwimValue -> SwimValue) -> MapDownlink {
        return syncMap(prio: 0.0, primaryKey: primaryKey)
    }
}
