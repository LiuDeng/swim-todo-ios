import Bolts


public protocol Downlink: class {

    /// The URI of the network endpoint to which this `Downlink` connects.
    var hostUri: SwimUri { get }

    /// The URI of the service instance to which this `Downlink` connects. An absolute URI resolved against `hostUri`.
    var nodeUri: SwimUri { get }

    /// The URI of the lane to which this `Downlink` connects.
    var laneUri: SwimUri { get }

    /// The properties of this `Downlink`.
    var laneProperties: LaneProperties { get }

    /// `true` if the network connection carrying this link is currently connected.
    var connected: Bool { get }

    /// `true` if this link should be automatically re-established after network connection failures.  The keep-alive mode can be changed at any time by assigning a new value to this property.
    var keepAlive: Bool { get set }

    /**
     - parameter delegate: Will be weakly referenced by this Downlink.
     */
    func addDelegate(delegate: DownlinkDelegate)

    func removeDelegate(delegate: DownlinkDelegate)

    /**
     Send a command to the remote lane to which this `Downlink` is
     connected.

     - returns: A BFTask representing the command.  This will succeed with
     nil result when the server acks the command, or it will fail if the
     command could not be sent.
     */
    func command(body body: SwimValue) -> BFTask

    /**
     Note that this is asynchronous, but there's no task to track success.
     This is because you might never get an ack for this request, e.g.
     if the server goes down before the request is handled, and there's
     no tracking inside this SDK for that.  We could add that, but it
     hasn't been necessary and this way we avoid lots of complexity.
     */
    func sendSyncRequest()

    /// Unregister this `Downlink` so that it no longer receives events.  If this was the only active link to a particular lane, then the link will be unlinked.
    func close()
}
