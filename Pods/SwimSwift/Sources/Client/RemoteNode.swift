class RemoteNode: RemoteScope, NodeScope {
    let channel: Channel
    let hostUri: SwimUri
    let nodeUri: SwimUri

    init(channel: Channel, host: SwimUri, node: SwimUri) {
        self.channel = channel
        self.hostUri = host
        self.nodeUri = node
    }

    func scope(lane lane: SwimUri) -> LaneScope {
        return RemoteLane(channel: channel, host: hostUri, node: nodeUri, lane: lane)
    }

    override func close() {
        channel.closeDownlinks(node: nodeUri)
    }
}
