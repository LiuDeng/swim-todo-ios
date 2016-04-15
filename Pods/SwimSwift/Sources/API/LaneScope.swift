/**
 Facilitates the creation and management of downlinks to a single lane of some service instance.
 */
public protocol LaneScope: class {

    /// The URI of the network endpoint to which the scope is bound.
    var hostUri: SwimUri { get }

    /// The URI of the service to which the scope is bound. An absolute URI resolved against `hostUri`.
    var nodeUri: SwimUri { get }

    /// The URI of the lane to which the scope is bound.
    var laneUri: SwimUri { get }

    func link(properties properties: LaneProperties) -> Downlink

    func sync(properties properties: LaneProperties) -> Downlink

    /**
     - parameter objectMaker: A callback that will construct a model object
     given the SwimValue received from the server.  This effectively tells
     the ListDownlink what type of model object should be constructed when
     a new value is received.
     */
    func syncList(properties properties: LaneProperties, objectMaker: (SwimValue -> SwimModelProtocolBase?)) -> ListDownlink

    func syncMap(properties properties: LaneProperties, primaryKey: SwimValue -> SwimValue) -> MapDownlink

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
