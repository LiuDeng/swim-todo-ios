private let log = SwimLogging.log


public class SwimClient: HostScope {
    public static let sharedInstance = SwimClient()

    public var protocols: [String]
    public var hostUri: SwimUri!

    private var _channel: Channel?
    private var channel: Channel {
        guard let hostUri = hostUri else {
            preconditionFailure("Must set hostUri before performing any other operation")
        }

        if _channel == nil {
            _channel = Channel(host: hostUri, protocols: protocols)
        }
        return _channel!
    }

    public init(host: SwimUri? = nil, protocols: [String] = []) {
        self.hostUri = host
        self.protocols = protocols
    }

    /**
     - parameter node: The destination service.
     - returns: A new `NodeScope` bound to the service at the given `node` running on `self.host`.

     ```swift
     let chat = client.scope(node: "/chat/public")
     ```
     */
    public func scope(node node: SwimUri) -> NodeScope {
        let host = node.hostUri
        return RemoteNode(channel: channel, host: host, node: node)
    }

    /**
     - parameter node: The destination service. Must contain a network authority component, as this specifies the destination host.
     - parameter lane: The destination lane in the service at the given `node`.
     - returns: A new `LaneScope` bound to the given `lane`.

     ```swift
        let chatRoom = client.scope(node: "/chat/public", lane: "chat/room")
     ```
     */
    public func scope(node node: SwimUri, lane: SwimUri) -> LaneScope {
        return RemoteLane(channel: channel, host: hostUri!, node: node, lane: lane)
    }

    /**
     - returns: A new `DownlinkBuilder` used to establish a new link to a lane of some remote service.

     ```swift
        let link = client.downlink()
            .node("/chat/public")
            .lane("chat/room")
            .sync()
     ```
     */
    public func downlink() -> DownlinkBuilder {
        return RemoteDownlinkBuilder(channel: channel)
    }

    public func link(node nodeSwimUri: SwimUri, lane: SwimUri, prio: Double) -> Downlink {
        return channel.link(node: nodeSwimUri, lane: lane, prio: prio)
    }

    public func sync(node nodeSwimUri: SwimUri, lane: SwimUri, prio: Double) -> Downlink {
        return channel.sync(node: nodeSwimUri, lane: lane, prio: prio)
    }

    public func syncList(node nodeSwimUri: SwimUri, lane: SwimUri, prio: Double) -> ListDownlink {
        return channel.syncList(node: nodeSwimUri, lane: lane, prio: prio)
    }

    public func syncMap(node nodeSwimUri: SwimUri, lane: SwimUri, prio: Double, primaryKey: SwimValue -> SwimValue) -> MapDownlink {
        return channel.syncMap(node: nodeSwimUri, lane: lane, prio: prio, primaryKey: primaryKey)
    }

    /**
     Send a command to a lane of a remote service.

     - parameter node: The destination service.
     - parameter lane: The destination lane in the service at the given `node`.
     - parameter body: The command to send, as a [RECON](https://github.com/swimit/recon-swift) structure.
     */
    public func command(node nodeSwimUri: SwimUri, lane: SwimUri, body: SwimValue) {
        channel.command(node: nodeSwimUri, lane: lane, body: body)
    }

    /**
     Authorizes all connections through this client with the provided
     recon `credentials` value.

     - parameter credentials: Might contain, for example, a
     [Google Sign-In ID token](https://developers.google.com/identity/sign-in/web/).

     ```swift
        client.auth(credentials: Value(Slot("googleIdToken", "")))
     ```
     */
    public func auth(credentials credentials: SwimValue) {
        channel.auth(credentials: credentials)
    }

    /// Unlinks all downlinks and closes the network connection associated with this client.
    public func close() {
        guard let c = _channel else {
            return
        }
        _channel = nil
        c.close()
    }


    /**
     Call this function from your AppDelegate.
     */
    public static func applicationDidBecomeActive() {
        log.verbose("applicationDidBecomeActive")
    }


    /**
     Call this function from your AppDelegate.
     */
    public static func applicationWillResignActive() {
        log.verbose("applicationWillResignActive")
    }


}
