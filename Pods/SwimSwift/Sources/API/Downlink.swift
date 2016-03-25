public protocol Downlink {

    /// The URI of the network endpoint to which this `Downlink` connects.
    var hostUri: SwimUri { get }

    /// The URI of the service instance to which this `Downlink` connects. An absolute URI resolved against `hostUri`.
    var nodeUri: SwimUri { get }

    /// The URI of the lane to which this `Downlink` connects.
    var laneUri: SwimUri { get }

    /// The priority level of this `Downlink`.
    var prio: Double { get }

    /// `true` if the network connection carrying this link is currently connected.
    var connected: Bool { get }

    /// `true` if this link should be automatically re-established after network connection failures.  The keep-alive mode can be changed at any time by assigning a new value to this property.
    var keepAlive: Bool { get set }

    var delegate: DownlinkDelegate? { get set }

    /// Send a command to the remote lane to which this `Downlink` is connected.
    func command(body body: SwimValue)

    /// Unregister this `Downlink` so that it no longer receives events.  If this was the only active link to a particular lane, then the link will be unlinked.
    func close()
}
