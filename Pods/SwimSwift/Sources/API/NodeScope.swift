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

    /// Unlinks all downlinks registered with the scope.
    func close()
}
