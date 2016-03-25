public protocol DownlinkBuilder {
    func host(hostUri: SwimUri) -> Self

    func node(nodeUri: SwimUri) -> Self

    func lane(laneUri: SwimUri) -> Self

    func prio(prio: Double) -> Self

    func keepAlive() -> Self

    func delegate(delegate: DownlinkDelegate) -> Self

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
