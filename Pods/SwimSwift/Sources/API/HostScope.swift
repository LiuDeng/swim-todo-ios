/**
 Facilitates the creation and management of downlinks to a single network endpoint.
 */
public protocol HostScope {

    func link(node node: SwimUri, lane: SwimUri, properties: LaneProperties) -> Downlink

    func sync(node node: SwimUri, lane: SwimUri, properties: LaneProperties) -> Downlink

    func syncMap(node node: SwimUri, lane: SwimUri, properties: LaneProperties, primaryKey: SwimValue -> SwimValue) -> MapDownlink

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
        return link(node: node, lane: lane, properties: LaneProperties())
    }

    public func sync(node node: SwimUri, lane: SwimUri) -> Downlink {
        return sync(node: node, lane: lane, properties: LaneProperties())
    }

    public func syncMap(node node: SwimUri, lane: SwimUri, primaryKey: SwimValue -> SwimValue) -> MapDownlink {
        return syncMap(node: node, lane: lane, properties: LaneProperties(), primaryKey: primaryKey)
    }
}
