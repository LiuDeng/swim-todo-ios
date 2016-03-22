public protocol DownlinkBuilder {
    func host(hostUri: SwimUri) -> Self

    func node(nodeUri: SwimUri) -> Self

    func lane(laneUri: SwimUri) -> Self

    func prio(prio: Double) -> Self

    func keepAlive() -> Self

    func delegate(delegate: DownlinkDelegate) -> Self

    func event(callback: EventMessage -> Void) -> Self

    func command(callback: CommandMessage -> Void) -> Self

    func willLink(callback: LinkRequest -> Void) -> Self

    func didLink(callback: LinkedResponse -> Void) -> Self

    func willSync(callback: SyncRequest -> Void) -> Self

    func didSync(callback: SyncedResponse -> Void) -> Self

    func willUnlink(callback: UnlinkRequest -> Void) -> Self

    func didUnlink(callback: UnlinkedResponse -> Void) -> Self

    func didConnect(callback: () -> Void) -> Self

    func didDisconnect(callback: () -> Void) -> Self

    func didClose(callback: () -> Void) -> Self

    /// Sets the `primaryKey` function used to extract unique keys from message bodies received over a `MapDownlink`.
    func primaryKey(primaryKey: SwimValue -> SwimValue) -> Self

    /// - returns: A `Downlink` parameterized by this builder's configuration.
    func link() -> Downlink

    /// - returns: A synchronized `Downlink` parameterized by this builder's configuration.
    func sync() -> Downlink

    /// - returns: A synchronized `ListDownlink` parameterized by this builder's configuration.
    func syncList() -> ListDownlink

    /// - returns: A synchronized `MapDownlink` parameterized by this builder's configuration.
    func syncMap() -> MapDownlink
}
