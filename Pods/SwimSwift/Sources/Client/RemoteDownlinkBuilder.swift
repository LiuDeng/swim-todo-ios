struct RemoteDownlinkBuilder: DownlinkBuilder {
    weak var client: SwimClient? = nil

    weak var channel: Channel? = nil

    weak var scope: RemoteScope? = nil

    var hostUri: SwimUri? = nil

    var nodeUri: SwimUri? = nil

    var laneUri: SwimUri? = nil

    var prio: Double = 0.0

    var keepalive: Bool = false

    var delegate: DownlinkDelegate? = nil

    var event: (EventMessage -> Void)? = nil

    var command: (CommandMessage -> Void)? = nil

    var willLink: (LinkRequest -> Void)? = nil

    var didLink: (LinkedResponse -> Void)? = nil

    var willSync: (SyncRequest -> Void)? = nil

    var didSync: (SyncedResponse -> Void)? = nil

    var willUnlink: (UnlinkRequest -> Void)? = nil

    var didUnlink: (UnlinkedResponse -> Void)? = nil

    var primaryKey: (SwimValue -> SwimValue)? = nil

    var didConnect: (() -> Void)? = nil

    var didDisconnect: (() -> Void)? = nil

    var didClose: (() -> Void)? = nil

    init(channel: Channel, scope: RemoteScope) {
        self.channel = channel
        self.scope = scope
    }

    init(channel: Channel) {
        self.channel = channel
    }

    init(client: SwimClient) {
        self.client =  client
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

    func event(callback: EventMessage -> Void) -> RemoteDownlinkBuilder {
        var builder = self
        builder.event = callback
        return builder
    }

    func command(callback: CommandMessage -> Void) -> RemoteDownlinkBuilder {
        var builder = self
        builder.command = callback
        return builder
    }

    func willLink(callback: LinkRequest -> Void) -> RemoteDownlinkBuilder {
        var builder = self
        builder.willLink = callback
        return builder
    }

    func didLink(callback: LinkedResponse -> Void) -> RemoteDownlinkBuilder {
        var builder = self
        builder.didLink = callback
        return builder
    }

    func willSync(callback: SyncRequest -> Void) -> RemoteDownlinkBuilder {
        var builder = self
        builder.willSync = callback
        return builder
    }

    func didSync(callback: SyncedResponse -> Void) -> RemoteDownlinkBuilder {
        var builder = self
        builder.didSync = callback
        return builder
    }

    func willUnlink(callback: UnlinkRequest -> Void) -> RemoteDownlinkBuilder {
        var builder = self
        builder.willUnlink = callback
        return builder
    }

    func didUnlink(callback: UnlinkedResponse -> Void) -> RemoteDownlinkBuilder {
        var builder = self
        builder.didUnlink = callback
        return builder
    }

    func didConnect(callback: () -> Void) -> RemoteDownlinkBuilder {
        var builder = self
        builder.didConnect = callback
        return builder
    }

    func didDisconnect(callback: () -> Void) -> RemoteDownlinkBuilder {
        var builder = self
        builder.didDisconnect = callback
        return builder
    }

    func didClose(callback: () -> Void) -> RemoteDownlinkBuilder {
        var builder = self
        builder.didClose = callback
        return builder
    }

    func primaryKey(primaryKey: SwimValue -> SwimValue) -> RemoteDownlinkBuilder {
        var builder = self
        builder.primaryKey = primaryKey
        return builder
    }

    func normalize() -> RemoteDownlinkBuilder {
        var builder = self
        if let hostUri = builder.hostUri, let nodeUri = builder.nodeUri {
            builder.nodeUri = hostUri.resolve(nodeUri)
        } else if let nodeUri = builder.nodeUri {
            builder.hostUri = SwimClient.getHostUri(node: nodeUri)
        } else {
            fatalError("DownlinkBuilder has no nodeUri")
        }
        if builder.channel == nil {
            builder.channel = builder.client!.getOrCreateChannel(builder.hostUri!)
            builder.client = nil
        }
        return builder
    }

    func registerDownlink(downlink: RemoteDownlink) {
        downlink.keepAlive = keepalive
        downlink.event = event
        downlink.command = command
        downlink.willLink = willLink
        downlink.didLink = didLink
        downlink.willSync = willSync
        downlink.didSync = didSync
        downlink.willUnlink = willUnlink
        downlink.didUnlink = didUnlink
        downlink.didConnect = didConnect
        downlink.didDisconnect = didDisconnect
        downlink.didClose = didClose
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
