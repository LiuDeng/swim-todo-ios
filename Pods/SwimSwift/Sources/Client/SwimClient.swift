public class SwimClient: SwimScope {
    public static let sharedInstance = SwimClient()

    let protocols: [String]

    var channels: [SwimUri: Channel] = [SwimUri: Channel]()

    public init(protocols: [String] = []) {
        self.protocols = protocols
    }

    func getOrCreateChannel(host: SwimUri) -> Channel {
        if let channel = channels[host] {
            return channel
        } else {
            let channel = Channel(host: host, protocols: protocols)
            channels[host] = channel
            return channel
        }
    }

    /**
      - returns: A new `HostScope` bound to the endpoint at the given `host` URI.

      ```swift
         let example = client.scope(host: "ws://swim.example.com")
      ```
    */
    public func scope(host host: SwimUri) -> HostScope {
        let channel = getOrCreateChannel(host)
        return RemoteHost(channel: channel, host: host)
    }

    /**
     - parameter host: The destination host.
     - parameter node: The destination service on the given `host`.
     - returns: A new `NodeScope` bound to the service at the given `node`.
     */
    public func scope(host host: SwimUri, node: SwimUri) -> NodeScope {
        let channel = getOrCreateChannel(host)
        return RemoteNode(channel: channel, host: host, node: node)
    }

    /**
     - parameter host: The destination host.
     - parameter node: The destination service on the given `host`.
     - parameter lane: The destination lane in the service at the given `node`.
     - returns: A new `LaneScope` bound to the given `lane`.
     */
    public func scope(host host: SwimUri, node: SwimUri, lane: SwimUri) -> LaneScope {
        let host = SwimClient.getHostUri(node: node)
        let channel = getOrCreateChannel(host)
        return RemoteLane(channel: channel, host: host, node: node, lane: lane)
    }

    /**
     - parameter node: The destination service. Must contain a network authority component, as this specifies the destination host.
     - returns: A new `NodeScope` bound to the service at the given `node`.

     ```swift
     let chat = client.scope(node: "ws://swim.example.com/chat/public")
     ```
     */
    public func scope(node node: SwimUri) -> NodeScope {
        let host = SwimClient.getHostUri(node: node)
        let channel = getOrCreateChannel(host)
        return RemoteNode(channel: channel, host: host, node: node)
    }

    /**
     - parameter node: The destination service. Must contain a network authority component, as this specifies the destination host.
     - parameter lane: The destination lane in the service at the given `node`.
     - returns: A new `LaneScope` bound to the given `lane`.

     ```swift
        let chatRoom = client.scope(node: "ws://swim.example.com/chat/public", lane: "chat/room")
     ```
     */
    public func scope(node node: SwimUri, lane: SwimUri) -> LaneScope {
        let host = SwimClient.getHostUri(node: node)
        let channel = getOrCreateChannel(host)
        return RemoteLane(channel: channel, host: host, node: node, lane: lane)
    }

    /**
     - returns: A new `DownlinkBuilder` used to establish a new link to a lane of some remote service.

     ```swift
        let link = client.downlink()
            .node("ws://swim.example.com/chat/public")
            .lane("chat/room")
            .sync()
     ```
     */
    public func downlink() -> DownlinkBuilder {
        return RemoteDownlinkBuilder(client: self)
    }

    public func link(host host: SwimUri, node nodeSwimUri: SwimUri, lane: SwimUri, prio: Double) -> Downlink {
        let channel = getOrCreateChannel(host)
        return channel.link(node: nodeSwimUri, lane: lane, prio: prio)
    }

    public func link(node nodeSwimUri: SwimUri, lane: SwimUri, prio: Double) -> Downlink {
        let host = SwimClient.getHostUri(node: nodeSwimUri)
        let channel = getOrCreateChannel(host)
        return channel.link(node: nodeSwimUri, lane: lane, prio: prio)
    }

    public func sync(host host: SwimUri, node nodeSwimUri: SwimUri, lane: SwimUri, prio: Double) -> Downlink {
        let channel = getOrCreateChannel(host)
        return channel.sync(node: nodeSwimUri, lane: lane, prio: prio)
    }

    public func sync(node nodeSwimUri: SwimUri, lane: SwimUri, prio: Double) -> Downlink {
        let host = SwimClient.getHostUri(node: nodeSwimUri)
        let channel = getOrCreateChannel(host)
        return channel.sync(node: nodeSwimUri, lane: lane, prio: prio)
    }

    public func syncList(host host: SwimUri, node nodeSwimUri: SwimUri, lane: SwimUri, prio: Double) -> ListDownlink {
        let channel = getOrCreateChannel(host)
        return channel.syncList(node: nodeSwimUri, lane: lane, prio: prio)
    }

    public func syncList(node nodeSwimUri: SwimUri, lane: SwimUri, prio: Double) -> ListDownlink {
        let host = SwimClient.getHostUri(node: nodeSwimUri)
        let channel = getOrCreateChannel(host)
        return channel.syncList(node: nodeSwimUri, lane: lane, prio: prio)
    }

    public func syncMap(host host: SwimUri, node nodeSwimUri: SwimUri, lane: SwimUri, prio: Double, primaryKey: SwimValue -> SwimValue) -> MapDownlink {
        let channel = getOrCreateChannel(host)
        return channel.syncMap(node: nodeSwimUri, lane: lane, prio: prio, primaryKey: primaryKey)
    }

    public func syncMap(node nodeSwimUri: SwimUri, lane: SwimUri, prio: Double, primaryKey: SwimValue -> SwimValue) -> MapDownlink {
        let host = SwimClient.getHostUri(node: nodeSwimUri)
        let channel = getOrCreateChannel(host)
        return channel.syncMap(node: nodeSwimUri, lane: lane, prio: prio, primaryKey: primaryKey)
    }

    /**
     Send a command to a lane of a remote service.

     - parameter host: The destination host.
     - parameter node: The destination service on the given `host`.
     - parameter lane: The destination lane in the service at the given `node`.
     - parameter body: The command to send, as a [RECON](https://github.com/swimit/recon-swift) structure.

    ```swift
       client.command(node: "ws://swim.example.com/chat/public", lane: "chat/roon", body: "Hello, world!")
    ```
     */
    public func command(host host: SwimUri, node nodeSwimUri: SwimUri, lane: SwimUri, body: SwimValue) {
        let channel = getOrCreateChannel(host)
        channel.command(node: nodeSwimUri, lane: lane, body: body)
    }

    /**
     Send a command to a lane of a remote service.

     - parameter node: The destination service. Must contain a network authority component, as this specifies the destination host.
     - parameter lane: The destination lane in the service at the given `node`.
     - parameter body: The command to send, as a [RECON](https://github.com/swimit/recon-swift) structure.
     */
    public func command(node nodeSwimUri: SwimUri, lane: SwimUri, body: SwimValue) {
        let host = SwimClient.getHostUri(node: nodeSwimUri)
        let channel = getOrCreateChannel(host)
        channel.command(node: nodeSwimUri, lane: lane, body: body)
    }

    /**
     Authorizes all connections to a `host` URI through `client` with the provided
     recon `credentials` value.  `credentials` might contain, for example, a
     [Google Sign-In ID token](https://developers.google.com/identity/sign-in/web/).
     Note that connections to public hosts may not require authorization.

     ```swift
        let client = SwimClient()
        client.auth(host: "ws://swim.example.com", credentials: Value(Slot("googleIdToken", "")))
     ```
     */
    public func auth(host host: SwimUri, credentials: SwimValue) {
        let channel = getOrCreateChannel(host)
        channel.auth(credentials: credentials)
    }

    /// Unlinks all downlinks, and closes all network connections, associated with the `client` connection pool.
    public func close() {
        let channels = self.channels
        self.channels.removeAll()
        for channel in channels.values {
            channel.close()
        }
    }

    static func getHostUri(node nodeSwimUri: SwimUri) -> SwimUri {
        var scheme = nodeSwimUri.scheme
        if scheme == nil || scheme!.name == "swim" {
            scheme = "ws"
        }
        return SwimUri(scheme: scheme, authority: nodeSwimUri.authority)
    }
}
