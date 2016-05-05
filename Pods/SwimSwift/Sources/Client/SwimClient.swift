import Bolts


private let log = SwimLogging.log


public class SwimClient {
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
     - returns: A new `NodeScope` bound to the service at the given `node` running on `self.hostUri`.

     ```swift
     let chat = client.scope(node: "/chat/public")
     ```
     */
    @warn_unused_result
    public func scope(node node: SwimUri) -> NodeScope {
        return RemoteNode(channel: channel, host: hostUri, node: node)
    }

    /**
     - parameter node: The destination service. Must contain a network authority component, as this specifies the destination host.
     - parameter lane: The destination lane in the service at the given `node`.
     - returns: A new `LaneScope` bound to the given `lane`.

     ```swift
        let chatRoom = client.scope(node: "/chat/public", lane: "chat/room")
     ```
     */
    @warn_unused_result
    public func scope(node node: SwimUri, lane: SwimUri) -> LaneScope {
        return RemoteLane(channel: channel, host: hostUri!, node: node, lane: lane)
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
    @warn_unused_result
    public func auth(credentials credentials: SwimValue) -> BFTask {
        return channel.auth(credentials: credentials)
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

        SwimGlobals.instance.dbManager?.applicationWillResignActive()
    }


    /**
     Call this function from your AppDelegate.
     */
    public static func applicationPerformFetchWithCompletionHandler(completionHandler: UIBackgroundFetchResult -> Void) {
        log.verbose("applicationPerformFetchWithCompletionHandler")

        completionHandler(.NoData)
    }


}
