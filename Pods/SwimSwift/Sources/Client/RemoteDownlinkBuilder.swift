struct RemoteDownlinkBuilder: DownlinkBuilder {
    weak var channel: Channel? = nil

    weak var scope: RemoteScope? = nil

    var hostUri: SwimUri? = nil

    var nodeUri: SwimUri? = nil

    var laneUri: SwimUri? = nil

    var prio: Double = 0.0

    var keepalive: Bool = false

    var delegate: DownlinkDelegate? = nil

    var primaryKey: (SwimValue -> SwimValue)? = nil

    init(channel: Channel, scope: RemoteScope) {
        self.channel = channel
        self.scope = scope
    }

    init(channel: Channel) {
        self.channel = channel
    }

    init(channel: Channel, scope: RemoteScope, host: SwimUri) {
        self.channel = channel
        self.scope = scope
        self.hostUri = host
    }

    init(channel: Channel, scope: RemoteScope, host: SwimUri, node: SwimUri) {
        self.channel = channel
        self.scope = scope
        self.hostUri = host
        self.nodeUri = node
    }

    init(channel: Channel, scope: RemoteScope, host: SwimUri, node: SwimUri, lane: SwimUri) {
        self.channel = channel
        self.scope = scope
        self.hostUri = host
        self.nodeUri = node
        self.laneUri = lane
    }

    func host(host: SwimUri) -> RemoteDownlinkBuilder {
        var builder = self
        builder.hostUri = host
        return builder
    }

    func node(node: SwimUri) -> RemoteDownlinkBuilder {
        var builder = self
        builder.nodeUri = node
        return builder
    }

    func lane(lane: SwimUri) -> RemoteDownlinkBuilder {
        var builder = self
        builder.laneUri = lane
        return builder
    }

    func prio(prio: Double) -> RemoteDownlinkBuilder {
        var builder = self
        builder.prio = prio
        return builder
    }

    func keepAlive() -> RemoteDownlinkBuilder {
        var builder = self
        builder.keepalive = true
        return builder
    }

    func delegate(delegate: DownlinkDelegate) -> RemoteDownlinkBuilder {
        var builder = self
        builder.delegate = delegate
        return builder
    }

    func primaryKey(primaryKey: SwimValue -> SwimValue) -> RemoteDownlinkBuilder {
        var builder = self
        builder.primaryKey = primaryKey
        return builder
    }

    private func normalize() -> RemoteDownlinkBuilder {
        var builder = self
        if let hostUri = builder.hostUri, let nodeUri = builder.nodeUri {
            builder.nodeUri = hostUri.resolve(nodeUri)
        } else if let nodeUri = builder.nodeUri {
            builder.hostUri = nodeUri.hostUri
        } else {
            fatalError("DownlinkBuilder has no nodeUri")
        }
        return builder
    }

    private func registerDownlink(downlink: RemoteDownlink) {
        downlink.delegate = delegate
        downlink.keepAlive = keepalive
        channel!.registerDownlink(downlink)
        if let scope = self.scope {
            scope.registerDownlink(downlink)
        }
    }

    func link() -> Downlink {
        let builder = normalize()
        let downlink = RemoteLinkedDownlink(channel: builder.channel!, scope: builder.scope, host: builder.hostUri!, node: builder.nodeUri!, lane: builder.laneUri!, prio: builder.prio)
        builder.registerDownlink(downlink)
        return downlink
    }

    func sync() -> Downlink {
        let builder = normalize()
        let downlink = RemoteSyncedDownlink(channel: builder.channel!, scope: builder.scope, host: builder.hostUri!, node: builder.nodeUri!, lane: builder.laneUri!, prio: builder.prio)
        builder.registerDownlink(downlink)
        return downlink
    }

    func syncList() -> ListDownlink {
        let builder = normalize()
        let downlink = RemoteListDownlink(channel: builder.channel!, scope: builder.scope, host: builder.hostUri!, node: builder.nodeUri!, lane: builder.laneUri!, prio: builder.prio)
        builder.registerDownlink(downlink)
        return downlink
    }

    func syncMap() -> MapDownlink {
        let builder = normalize()
        let downlink = RemoteMapDownlink(channel: builder.channel!, scope: builder.scope, host: builder.hostUri!, node: builder.nodeUri!, lane: builder.laneUri!, prio: builder.prio, primaryKey: builder.primaryKey!)
        builder.registerDownlink(downlink)
        return downlink
    }
}
